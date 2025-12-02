#################################################
# HelloID-Conn-Prov-Target-EAL-ATS360-Update
# PowerShell V2
#################################################

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
        $correlatedAccount | Add-Member -MemberType NoteProperty -Name 'middleName' -Value $correlatedAccount.insertion
        $outputContext.PreviousData = ($correlatedAccount | Select-Object -Property $outputContext.data.PSObject.Properties.Name)

        $splatCompareProperties = @{
            ReferenceObject  = @($correlatedAccount.PSObject.Properties)
            DifferenceObject = @($actionContext.Data.PSObject.Properties)
        }
        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        if ($propertiesChanged) {
            $action = 'UpdateAccount'
        } else {
            $action = 'NoChanges'
        }
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ( $action) {
        'UpdateAccount' {
            Write-Information "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"

            $body = $actionContext.Data | Select-Object -Property $propertiesChanged.Name
            if (-not($propertiesChanged.Name -contains 'lastName')) {
                $body | Add-Member -MemberType NoteProperty -Name 'lastName' -Value $correlatedAccount.lastName
            }

            $splatUpdateUserParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/v1.1/BadgeHolder/Import?keyField=externalId&keyValue=$($correlatedAccount.externalId)"
                Method      = 'Patch'
                Body        = ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10)))
                contentType = 'application/json'
            }
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating EAL-ATS360 account with accountReference: [$($actionContext.References.Account)]"
                $null = Invoke-RestMethod @splatUpdateUserParams

            } else {
                Write-Information "[DryRun] Update EAL-ATS360 account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.name -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "No changes to EAL-ATS360 account with accountReference: [$($actionContext.References.Account)]"
            $outputContext.Success = $true
            break
        }

        'NotFound' {
            Write-Information "EAL-ATS360 account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "EAL-ATS360 account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-EAL-ATS360Error -ErrorObject $ex
        $auditLogMessage = "Could not update EAL-ATS360 account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not update EAL-ATS360 account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}
