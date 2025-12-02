##################################################
# HelloID-Conn-Prov-Target-EAL-ATS360-Disable
# PowerShell V2
##################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-EAL-ATS360Error {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            if (-not[string]::IsNullOrWhiteSpace($errorDetailsObject.error.message)) {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.error.message
            } elseif (-not[string]::IsNullOrWhiteSpace($errorDetailsObject.value)) {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.value
            } else {
                $httpErrorObj.FriendlyMessage = "[$($httpErrorObj.ErrorDetails)]"
            }
        } catch {
            $httpErrorObj.FriendlyMessage = "[$($httpErrorObj.ErrorDetails)]"
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information 'Verifying if a EAL-ATS360 account exists'
    $splatGetUserParams = @{
        Uri    = "$($actionContext.Configuration.BaseUrl)/v1.1/BadgeHolder?`$filter=id eq $($actionContext.References.Account)"
        Method = 'GET'
    }
    $correlatedAccount = (Invoke-RestMethod @splatGetUserParams).value | Select-Object -First 1

    if ($null -ne $correlatedAccount) {
        $action = 'DisableAccount'
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DisableAccount' {
            $body = @{
                lastName       = $correlatedAccount.lastName
                isBlocked      = $true
                validityPeriod = @{
                    start      = (Get-Date).AddDays(-1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    expiration = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }

            $splatDisableUserParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/v1.1/BadgeHolder/Import?keyField=externalId&keyValue=$($correlatedAccount.externalId)"
                Method      = 'Patch'
                Body        = ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10)))
                contentType = 'application/json'
            }

            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Disabling EAL-ATS360 account with accountReference: [$($actionContext.References.Account)]"
                $null = Invoke-RestMethod @splatDisableUserParams
            } else {
                Write-Information "[DryRun] Disable EAL-ATS360 account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Disable account [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "EAL-ATS360 account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "EAL-ATS360 account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-EAL-ATS360Error -ErrorObject $ex
        $auditLogMessage = "Could not disable EAL-ATS360 account. Error: $($errorObj.FriendlyMessage). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not disable EAL-ATS360 account. Error: $($_.Exception.Message). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}