# add_test_name_logging.ps1
# Ever come across a codebase where you may find you have the need to log out the name of every test as they start,
# but cant be bothered to manually edit over a thousand tests? You're in the right place.
# Written for some C# code using mstest testing framework but you can edit the lines to look for and the methods
# to use for getting the function name / logging out the results.
#
## Usage:
# ./add_test_name_logging.ps1 -path *Path to repository* -dryRun
#### Will do a dry run, just editing the first file it finds and outputting the intended result to a test.cs file in the cwd.
# ./add_test_name_logging.ps1 -path *Path to repository* 
#### The real deal - will change all files matching the check @ line 56 and then all lines matching the other checks
# ./add_test_name_logging.ps1 -path *path to file* -single
#### The real deal - but only works it's magic on one file. Can also be a dry run.

param(
    # Path to hunt for tests in
    [Parameter(Mandatory=$true)]
    [string]
    $path,

    # Single - Switch to determine whether path should be treated as a single file.
    [Parameter(Mandatory=$false)]
    [switch]
    $single,

    # DryRun - Run only on the first file found, don't edit it but output the would-be new file contents to a file
    # called tests.cs
    [Parameter(Mandatory=$false)]
    [switch]
    $dryRun
)

class FileResults {
    [string]$fileContents
    [int]$editCount
    [bool]$refAdded

    FileResults(){
        $this.fileContents = ""
        $this.editCount = 0
        $this.refAdded = $false
    }
}

function getLine {
    param (
        [string]$originalLine
    )
    # line to set var for getting the name of the current method
    $getMethodNameCommand = "string testName = System.Reflection.MethodBase.GetCurrentMethod().Name;"
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

function processLines {
    param(
        # File (object) for processing
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]
        $file
    )
    $fileInfo = [FileResults]::new()
    $checkNextUsing = $false
    $nextLine = $false
    $printNextLine = $false

    # Read file line-by-line
    foreach($line in [System.IO.File]::ReadLines($file.FullName)){
        if(($line -Like "using *") -and -not $fileInfo.refAdded){
            if($line -Like "*using log4net.Core*" -or $line -Like "*using log4net*"){
                $checkNextUsing = $false
            } else {
                $checkNextUsing = $true
            }
        } elseif ($checkNextUsing){

            #reached end of "using" statements with no log4net ref
            $fileInfo.refAdded = $true
            $line =
@"
using log4net.Core;
using log4net;
$line
"@ # Imagine a world where this could be perfectly indented *sigh*
            $checkNextUsing = $false
        }

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
                Write-Output "EEK! Unexpected Line :( ""$line"""
                continue
            } else {
                # Work some magic! (Edit the line to contain our values)
                $line = getLine -originalLine $line
                $fileInfo.editCount += 1
            }

            # Reset these for the next test we find.
            $printNextLine = $false
            $nextLine = $false
        }

        # Take the line, edited or not, and add it into a variable to set the contents of the file.
        $fileInfo.fileContents += "$line
" # <- This lil' guy needs to stay here unless you want a single line class.

    }
    return $fileInfo
}

function writeFileChanges {
    param(
        # New contents for file
        [Parameter(Mandatory=$true)]
        [string]
        $contents,
        # File info object
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]
        $file
    )
    if($dryRun.IsPresent){
        $contents | Set-Content -Path "tests.cs"
    } else {
        $contents | Set-Content -Path $file.FullName
    }

}

# Counts for end report
$countFiles = 0
$countTestsEdited = 0
$countLogFrameworkAdded = 0

if($single.IsPresent)
{
    # Check file actually exists, exit nicely.
    try{
        $file = Get-Item -Path $path
    } catch {
        Write-Output [string]::Format("Error getting file $path : {0}", $Error[0])
    }

    # Get edited contents
    $newFileInfo = (processLines -file $file)
    
    # Adjust counts
    $countFiles = 1
    $countTestsEdited += $newFileInfo.editCount
    if($newFileInfo.refAdded){$countLogFrameworkAdded += 1}

    # Logging and writing
    writeFileChanges -contents $newFileInfo.fileContents -file $file
    Write-Output "Added name logging to $countTestsEditedInFile tests"
}
else
{
    Get-ChildItem -Recurse -Path $path | % {
        # Look only for files that end in tests or test.
        if (($_.Name -Like "*Tests.cs" -or $_.Name -Like "*Test.cs") -and -not ($_.Name -like "*.csproj"))
        {
            Write-Output "Found $($_.Name)"
            # Get edited contents
            $newFileInfo = (processLines -file $_)

            # Adjust counts
            $countTestsEdited += $newFileInfo.editCount
            if($newFileInfo.refAdded){$countLogFrameworkAdded += 1}

            # A little logging here
            Write-Output ([string]::Format("Added name logging to {0} tests.", $newFileInfo.editCount))
            
            # A little writing there
            writeFileChanges -contents $newFileInfo.fileContents -file $_

            if($dryRun.IsPresent -and ($countFiles -eq 1)){
                Write-Output "Found $countFiles class(es) and updated $countTestsEdited test(s). Added logging framework to $countLogFrameworkAdded namespace(s)."
                break # This is weird, it exits the entire script rather than the For-Each loop it exists in? Thus the double logging here and the final line.
            }

        }
    }
}

Write-Output "Found $countFiles class(es) and updated $countTestsEdited test(s). Added logging framework to $countLogFrameworkAdded namespace(s)."