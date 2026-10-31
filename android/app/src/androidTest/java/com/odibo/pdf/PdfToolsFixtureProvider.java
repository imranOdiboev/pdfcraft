package com.odibo.pdf;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Test APK only. Java/Android APIs allow its separate process to start without
 * the target APK's deduplicated Kotlin runtime. All source documents are read-only. */
public final class PdfToolsFixtureProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }

    private File source(Uri uri) throws FileNotFoundException {
        String id = uri.getLastPathSegment();
        if (!("first".equals(id) || "second".equals(id)) || getContext() == null) {
            throw new FileNotFoundException("Unknown synthetic fixture");
        }
        File file = new File(getContext().getCacheDir(), "odibo-fixture-" + id + ".pdf");
        if (!file.exists()) {
            String[] colors = "first".equals(id) ? new String[]{"1 0 0", "0 1 0"} : new String[]{"0 0 1", "1 1 0"};
            try (FileOutputStream output = new FileOutputStream(file)) { output.write(pdf(colors)); }
            catch (IOException failure) {
                FileNotFoundException error = new FileNotFoundException("Could not create synthetic fixture");
                error.initCause(failure);
                throw error;
            }
        }
        return file;
    }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Read-only synthetic source");
        return ParcelFileDescriptor.open(source(uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        final File file;
        try { file = source(uri); } catch (FileNotFoundException error) { throw new IllegalArgumentException("Unknown fixture", error); }
        String[] columns = projection != null ? projection : new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE};
        MatrixCursor cursor = new MatrixCursor(columns);
        Object[] row = new Object[columns.length];
        for (int index = 0; index < columns.length; index++) {
            if (OpenableColumns.DISPLAY_NAME.equals(columns[index])) row[index] = uri.getLastPathSegment() + ".pdf";
            else if (OpenableColumns.SIZE.equals(columns[index])) row[index] = file.length();
        }
        cursor.addRow(row);
        return cursor;
    }

    @Override public String getType(Uri uri) { return "application/pdf"; }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] selectionArgs) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { throw new UnsupportedOperationException(); }

    private static void write(ByteArrayOutputStream out, String text) {
        byte[] bytes = text.getBytes(StandardCharsets.US_ASCII);
        out.write(bytes, 0, bytes.length);
    }

    private static byte[] pdf(String[] colors) {
        List<String> objects = new ArrayList<>();
        objects.add("<< /Type /Catalog /Pages 2 0 R >>");
        objects.add("<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>");
        objects.add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 5 0 R >>");
        objects.add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 6 0 R >>");
        for (String color : colors) {
            String content = color + " rg\n20 20 150 250 re f\n";
            objects.add("<< /Length " + content.getBytes(StandardCharsets.US_ASCII).length + " >>\nstream\n" + content + "endstream");
        }
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        List<Integer> offsets = new ArrayList<>();
        offsets.add(0);
        write(bytes, "%PDF-1.4\n");
        for (int index = 0; index < objects.size(); index++) {
            offsets.add(bytes.size());
            write(bytes, (index + 1) + " 0 obj\n" + objects.get(index) + "\nendobj\n");
        }
        int start = bytes.size();
        write(bytes, "xref\n0 " + offsets.size() + "\n0000000000 65535 f \n");
        for (int index = 1; index < offsets.size(); index++) write(bytes, String.format(Locale.ROOT, "%010d 00000 n \n", offsets.get(index)));
        write(bytes, "trailer\n<< /Size " + offsets.size() + " /Root 1 0 R >>\nstartxref\n" + start + "\n%%EOF\n");
        return bytes.toByteArray();
    }
}
