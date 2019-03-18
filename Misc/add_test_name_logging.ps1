# add_test_name_logging.ps1
# Ever come across a codebase where you may find you have the need to log out the name of every test as they start,
# but cant be bothered to manually edit over a thousand tests? You're in the right place.
# Written for some C# code using mstest testing framework but you can edit the lines to look for and the methods
# to use for getting the function name / logging out the results.

param(
    # Path to hunt for tests in
    [Parameter(Mandatory=$true)]
    [string]
    $pathToHunt,

    # DryRun - Run only on the first file found, don't edit it but output the would-be new file contents to a file
    # called tests.cs
    [Parameter(Mandatory=$false)]
    [switch]
    $dryRun
)


function getLine {
    param (
        [string]$originalLine
    )
    # line to set var for getting the name of the current method
    $getMethodNameCommand = "string testName = System.Reflection.MethodBase.GetCurrentMethod.Name;"
    # line to log that variable
    $logCall = "log.Info(String.Format(""Starting Test: {0}"", testName));"

    # Get the spacing that prepends the opening brace to keep the code we add in format.
    $space = $originalLine.split("\{", 2)

    $line =
@"
$originalLine
$space   $getMethodNameCommand
$space   $logCall
"@

    return $line
}

# Counts and checks
$countFiles = 0
$countTestsEdited = 0
$nextLine = $false
$printNextLine = $false

Get-ChildItem -Recurse -Path $pathTohunt | %{
    # Look only for files that end in tests or test.
    if ($_.Name -Like "*Tests.cs" -or $_.Name -Like "*Test.cs")
    {
        $countFiles += 1
        Write-Output "Found $($_.Name)"
        $countTestsEditedInFile = 0

        $newFileContents = ""

        # Read file line-by-line
        foreach($line in [System.IO.File]::ReadLines($_.FullName)){
            if($line -Like "*TestMethod*" -and -not ($line -like "*region*") -and -not ($line -like "*//*") -and -not ($line -like "*/\**")){
                # If we find a method tagged as a test we assume the next line is its declaration.
                $nextLine = $true
            } elseif ($nextLine) {
                # If it really is its declaration, we expect the next line to be the opening brace
                if ($line -Like "*public void*"){
                    $printNextLine = $true
                }

                # Sometimes tests are tagged with expected exceptions, if so check the next line
                if($line -Like "*ExpectedException*"){
                    $nextLine = $true
                    continue
                }

                $nextLine = $false
            } elseif ($printNextLine) {
                # If we set printNextLine we're fairly certain we're now working with an opening brace.
                
                # Sanity
                if(-not ($line -Like "*{*")){
                    Write-Output "EEK! Unexpected Line D: : $line"
                    continue
                } else {
                    # Work some magic! (Edit the line to contain our values)
                    $line = getLine -originalLine $line
                    $countTestsEditedInFile += 1
                    $countTestsEdited += 1
                }

                # Reset these for the next test we find.
                $printNextLine = $false
                $nextLine = $false
            }

            # Take the line, edited or not, and add it into a variable to set the contents of the file.
            $newFileContents += "
$line"

        }

        Write-Output "Added name logging to $countTestsEditedInFile tests."
        if($dryRun.IsPresent){
            "$newFileContents" | Set-Content -Path "tests.cs"
        } else {
            "$newFileContents" | Set-Content -Path $_.FullName
        }

        if($dryRun.IsPresent -and ($countFiles -eq 1)){
            break
        }

    }

}

Write-Output "Found $countFiles classes and updated $countTestsEdited tests"