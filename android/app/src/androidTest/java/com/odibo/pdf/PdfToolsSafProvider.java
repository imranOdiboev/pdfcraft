package com.odibo.pdf;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Test APK only: SAF URI/stream contract and controlled failures. No Kotlin or
 * target-app dependencies are required by this standalone provider process. */
public final class PdfToolsSafProvider extends ContentProvider {
    public static final String AUTHORITY = "com.odibo.pdf.test.saf";
    private final Object lock = new Object();
    @Override public boolean onCreate() { return true; }

    private static void text(File file, String value, boolean append) {
        try (FileOutputStream output = new FileOutputStream(file, append)) { output.write(value.getBytes(StandardCharsets.UTF_8)); }
        catch (IOException error) { throw new IllegalStateException("Synthetic provider storage failed", error); }
    }

    private File folder(String token) {
        if (token == null || !token.matches("(success|alias|deny|mismatch|cancel)-[0-9a-f-]{36}") || getContext() == null) {
            throw new IllegalArgumentException("Invalid synthetic tree");
        }
        File dir = new File(getContext().getCacheDir(), "saf-" + token);
        if (!dir.isDirectory() && !dir.mkdirs()) throw new IllegalStateException("Synthetic tree unavailable");
        File source = new File(dir, "source");
        if (!source.exists()) text(source, "Synthetic original: must never be overwritten", false);
        return dir;
    }

    private String[] id(Uri uri) throws FileNotFoundException {
        String[] parts = DocumentsContract.getDocumentId(uri).split(":", -1);
        if (parts.length != 2 || !parts[1].matches("source|out-[0-9a-f-]{36}")) throw new FileNotFoundException("Invalid synthetic document");
        folder(parts[0]);
        return parts;
    }

    private static void event(File dir, String name) { text(new File(dir, "." + name), "1\n", true); }
    private static int count(File dir, String name) {
        File file = new File(dir, "." + name);
        if (!file.exists()) return 0;
        int result = 0;
        try (BufferedReader input = new BufferedReader(new FileReader(file))) {
            while (input.readLine() != null) result++;
        } catch (IOException error) { throw new IllegalStateException("Synthetic event log unavailable", error); }
        return result;
    }

    @SuppressWarnings("deprecation")
    @Override public Bundle call(String method, String arg, Bundle extras) {
        synchronized (lock) {
            if ("qa:stats".equals(method)) {
                File dir = folder(arg);
                Bundle result = new Bundle();
                result.putInt("creates", count(dir, "creates"));
                result.putInt("writes", count(dir, "writes"));
                result.putInt("readbacks", count(dir, "readbacks"));
                int outputs = 0;
                File[] files = dir.listFiles();
                if (files != null) for (File file : files) if (file.getName().startsWith("out-")) outputs++;
                result.putInt("outputs", outputs);
                return result;
            }
            if (!"android:createDocument".equals(method)) throw new UnsupportedOperationException();
            Uri parent = extras == null ? null : extras.getParcelable("uri");
            if (parent == null) throw new IllegalArgumentException("Missing synthetic parent");
            String token = DocumentsContract.getTreeDocumentId(parent);
            File dir = folder(token);
            event(dir, "creates");
            String name = token.startsWith("alias-") ? "source" : "out-" + UUID.randomUUID();
            if (!"source".equals(name)) {
                try { if (!new File(dir, name).createNewFile()) throw new IllegalStateException("Synthetic destination exists"); }
                catch (IOException error) { throw new IllegalStateException("Synthetic destination failed", error); }
            }
            Bundle result = new Bundle();
            result.putParcelable("uri", DocumentsContract.buildDocumentUriUsingTree(parent, token + ":" + name));
            return result;
        }
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        synchronized (lock) {
            String[] columns = projection != null ? projection : new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID};
            String token = DocumentsContract.getTreeDocumentId(uri);
            File dir = folder(token);
            List<String> names = new ArrayList<>();
            if ("children".equals(uri.getLastPathSegment())) {
                File[] files = dir.listFiles();
                if (files != null) for (File file : files) {
                    String name = file.getName();
                    if ("source".equals(name) || name.startsWith("out-")) names.add(name);
                }
            } else {
                try { names.add(id(uri)[1]); }
                catch (FileNotFoundException error) { throw new IllegalArgumentException("Unknown synthetic document", error); }
            }
            MatrixCursor cursor = new MatrixCursor(columns);
            for (String name : names) {
                Object[] row = new Object[columns.length];
                for (int index = 0; index < columns.length; index++) {
                    String column = columns[index];
                    if (DocumentsContract.Document.COLUMN_DOCUMENT_ID.equals(column)) row[index] = token + ":" + name;
                    else if (DocumentsContract.Document.COLUMN_DISPLAY_NAME.equals(column)) row[index] = name + ".pdf";
                    else if (DocumentsContract.Document.COLUMN_MIME_TYPE.equals(column)) row[index] = "application/pdf";
                    else if (DocumentsContract.Document.COLUMN_SIZE.equals(column)) row[index] = new File(dir, name).length();
                }
                cursor.addRow(row);
            }
            return cursor;
        }
    }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        synchronized (lock) {
            String[] parts = id(uri);
            String token = parts[0];
            String name = parts[1];
            File dir = folder(token);
            if ("r".equals(mode)) {
                if (!"source".equals(name)) event(dir, "readbacks");
                File file = new File(dir, name);
                if (!"source".equals(name) && token.startsWith("mismatch-")) {
                    file = new File(dir, ".bad-readback");
                    text(file, "provider corrupted read-back", false);
                }
                return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
            }
            event(dir, "writes");
            if ("source".equals(name) || token.startsWith("deny-")) throw new FileNotFoundException("Controlled test provider write refusal");
            return ParcelFileDescriptor.open(new File(dir, name), ParcelFileDescriptor.MODE_WRITE_ONLY | ParcelFileDescriptor.MODE_TRUNCATE);
        }
    }

    @Override public String getType(Uri uri) { return "application/pdf"; }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] selectionArgs) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { throw new UnsupportedOperationException(); }
}
