// Helper function to run PowerShell Commands
def posh(cmd) {
    bat 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command "& ' + cmd + '"'
}

// helper function to run PowerShell files + args
def posh_file(file, args){
    if(args){
        bat 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "' + file + '" ' + args
    } else {
        bat 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "' + file + '"'
    }
}