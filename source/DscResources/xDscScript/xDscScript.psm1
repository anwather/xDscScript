$script:localizedData = ConvertFrom-StringData @'
GetTargetResourceStartVerboseMessage = Begin executing get script.
GetScriptThrewError = The get script threw an error.
GetScriptDidNotReturnHashtable = The get script did not return a hashtable.
GetTargetResourceEndVerboseMessage = End executing get script.
SetTargetResourceStartVerboseMessage = Begin executing set script.
SetScriptThrewError = The set script threw an error.
SetTargetResourceEndVerboseMessage = End executing set script.
TestTargetResourceStartVerboseMessage = Begin executing test script.
TestScriptThrewError = The test script threw an error.
TestScriptDidNotReturnBoolean = The test script did not return a boolean.
TestTargetResourceEndVerboseMessage = End executing test script.
ExecutingScriptMessage = Executing script: {0}
'@

class Reason {
    [DscProperty()]
    [string] $Code
  
    [DscProperty()]
    [string] $Phrase
}

[DscResource()]
class xDscScript {

    [DscProperty(Key)]
    [string] $TestScript

    [DscProperty(Key)]
    [string] $SetScript

    [DscProperty(NotConfigurable)]
    [Reason[]]$Reasons
    
    # Gets the resource's current state.
    [xDscScript] Get() {

        $returnReason = [Reason]::new()
        $returnReason.Code = "script:script:testresult"

        $result = TestTargetResource -TestScript $this.TestScript

        switch ($result) {
            $true { $returnReason.Phrase = "Test has returned a true result" }
            $false { $returnReason.Phrase = "Test has returned a false result" }
            default { $returnReason.Phrase = "Test has returned a unknown result" }
        }

        $this.Reasons = @($returnReason)

        return $this

    }
    
    # Sets the desired state of the resource.
    [void] Set() {
        SetTargetResource -SetScript $this.SetScript
    }
    
    # Tests if the resource is in the desired state.
    [bool] Test() {
        $result = TestTargetResource -TestScript $this.TestScript
        return $result
    }
}

function SetTargetResource {
    [CmdletBinding()]
    param
    (

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SetScript,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Write-Verbose -Message $script:localizedData.SetTargetResourceStartVerboseMessage

    $invokeScriptParameters = @{
        ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($SetScript)
    }

    if ($PSBoundParameters.ContainsKey('Credential')) {
        $invokeScriptParameters['Credential'] = $Credential
    }

    $invokeScriptResult = Invoke-Script @invokeScriptParameters

    if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord]) {
        New-InvalidOperationException -Message $script:localizedData.SetScriptThrewError -ErrorRecord $invokeScriptResult
    }

    Write-Verbose -Message $script:localizedData.SetTargetResourceEndVerboseMessage
}

function TestTargetResource {
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $TestScript,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Write-Verbose -Message $script:localizedData.TestTargetResourceStartVerboseMessage

    $invokeScriptParameters = @{
        ScriptBlock = [System.Management.Automation.ScriptBlock]::Create($TestScript)
    }

    if ($PSBoundParameters.ContainsKey('Credential')) {
        $invokeScriptParameters['Credential'] = $Credential
    }

    $invokeScriptResult = Invoke-Script @invokeScriptParameters

    # If the script is returing multiple objects, then we consider the last object to be the result of the script execution.
    if ($invokeScriptResult -is [System.Object[]] -and $invokeScriptResult.Count -gt 0) {
        $invokeScriptResult = $invokeScriptResult[$invokeScriptResult.Count - 1]
    }

    if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord]) {
        New-InvalidOperationException -Message $script:localizedData.TestScriptThrewError -ErrorRecord $invokeScriptResult
    }

    if ($null -eq $invokeScriptResult -or -not ($invokeScriptResult -is [System.Boolean])) {
        New-InvalidArgumentException -ArgumentName 'TestScript' -Message $script:localizedData.TestScriptDidNotReturnBoolean
    }

    Write-Verbose -Message $script:localizedData.TestTargetResourceEndVerboseMessage

    return $invokeScriptResult
}

function Invoke-Script {
    [OutputType([System.Object])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    $scriptResult = $null

    try {
        Write-Verbose -Message ($script:localizedData.ExecutingScriptMessage -f $ScriptBlock)

        if ($null -ne $Credential) {
            $scriptResult = Invoke-Command -ScriptBlock $ScriptBlock -Credential $Credential -ComputerName .
        }
        else {
            $scriptResult = & $ScriptBlock
        }
    }
    catch {
        # Surfacing the error thrown by the execution of the script
        $scriptResult = $_
    }

    return $scriptResult
}

function New-InvalidArgumentException {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'ArgumentException' `
        -ArgumentList @($Message, $ArgumentName)
    $newObjectParams = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @($argumentException, $ArgumentName, 'InvalidArgument', $null)
    }
    $errorRecord = New-Object @newObjectParams

    throw $errorRecord
}

function New-InvalidOperationException {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $Message) {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException'
    }
    elseif ($null -eq $ErrorRecord) {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @( $Message )
    }
    else {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @( $Message, $ErrorRecord.Exception )
    }

    $newObjectParams = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @( $invalidOperationException.ToString(), 'MachineStateIncorrect', 'InvalidOperation', $null )
    }

    $errorRecordToThrow = New-Object @newObjectParams
    throw $errorRecordToThrow
}
