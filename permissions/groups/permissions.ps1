############################################################
# HelloID-Conn-Prov-Target-EAL-ATS360-Permissions-Group
# PowerShell V2
############################################################

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
    Write-Information 'Retrieving permissions'
    $pageSize = 100
    $skip = 0
    do {
        $splatGetPermissionsParams = @{
            Uri    = "$($actionContext.Configuration.BaseUrl)/v1.1/DoorProfile?`$top=$($pageSize)&`$skip=$($skip)&`$count=true"
            Method = 'GET'
        }
        $response = (Invoke-RestMethod @splatGetPermissionsParams)

        foreach ($permission in $response.value) {
            $outputContext.Permissions.Add(
                @{
                    DisplayName    = $permission.name
                    Identification = @{
                        Reference = $permission.id
                    }
                }
            )
        }

        $skip += $pageSize
    } while (($skip -le $response.'@odata.count'))
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-EAL-ATS360Error -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
}
