# Release test-owned process handles after proving normal shutdown. A signalled
# process object may outlive its executable; retaining its handle can retain the
# image section and prevent an exclusive installer check from reopening the EXE.
function Close-OdiboGuiProcess([Diagnostics.Process]$Process) {
    if (-not $Process.WaitForExit(15000)) { throw 'GUI did not finish normal shutdown.' }
    if ($Process.ExitCode -ne 0) { throw 'GUI returned an error during normal shutdown.' }
    $Process.Dispose()
}
