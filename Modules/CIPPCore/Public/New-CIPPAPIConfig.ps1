

function New-CIPPAPIConfig {
    [CmdletBinding()]
    param (
        $APIName = "CIPP API Config",
        $ExecutingUser
    )

    try {
        $CreateBody = @"
{"api":{"oauth2PermissionScopes":[{"adminConsentDescription":"Allow the application to access CIPP-API on behalf of the signed-in user.","adminConsentDisplayName":"Access CIPP-API","id":"ba7ffeff-96ea-4ac4-9822-1bcfee9adaa4","isEnabled":true,"type":"User","userConsentDescription":"Allow the application to access CIPP-API on your behalf.","userConsentDisplayName":"Access CIPP-API","value":"user_impersonation"}]},"displayName":"CIPP-API","requiredResourceAccess":[{"resourceAccess":[{"id":"e1fe6dd8-ba31-4d61-89e7-88639da4683d","type":"Scope"}],"resourceAppId":"00000003-0000-0000-c000-000000000000"}],"signInAudience":"AzureADMyOrg","web":{"homePageUrl":"https://cipp.app","implicitGrantSettings":{"enableAccessTokenIssuance":false,"enableIdTokenIssuance":true},"redirectUris":["https://$($ENV:Website_hostname)/.auth/login/aad/callback"]}}
"@
        Write-Host "Creating app"
        $APIApp = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications" -NoAuthCheck $true -type POST -body $CreateBody
        Write-Host "Creating password"
        $APIPassword = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($APIApp.id)/addPassword"  -NoAuthCheck $true -type POST -body "{`"passwordCredential`":{`"displayName`":`"Generated by API Setup`",`"startDateTime`":`"2023-07-20T12:47:59.217Z`",`"endDateTime`":`"2033-07-20T12:47:59.217Z`"}}"
        Write-Host "Adding App URL"
        $APIIdUrl = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($APIApp.id)"  -NoAuthCheck $true -type PATCH -body "{`"identifierUris`":[`"api://$($APIApp.appId)`"]}"
        Write-Host "Adding serviceprincipal"
        $ServicePrincipal = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/serviceprincipals"  -NoAuthCheck $true -type POST -body "{`"accountEnabled`":true,`"appId`":`"$($APIApp.appId)`",`"displayName`":`"CIPP-API`",`"tags`":[`"WindowsAzureActiveDirectoryIntegratedApp`",`"AppServiceIntegratedApp`"]}"
        Write-Host "getting settings"
        $subscription = $($ENV:WEBSITE_OWNER_NAME).Split('+')[0]
        Write-Host "Subscription is $subscription"
        Write-Host "Resource Group is $($ENV:ResourceGroupName)"
        Write-Host "Site Name is $($ENV:WEBSITE_SITE_NAME)"
        
        $CurrentSettings = New-GraphGetRequest -uri "https://management.azure.com/subscriptions/$($subscription)/resourceGroups/$ENV:ResourceGroupName/providers/Microsoft.Web/sites/$ENV:WEBSITE_SITE_NAME/Config/authsettingsV2/list?api-version=2018-11-01" -NoAuthCheck $true -scope "https://management.azure.com/.default"
        Write-Host "setting settings"
        $currentSettings.properties.identityProviders.azureActiveDirectory = @{
            registration = @{
                clientId     = $APIApp.appId
                openIdIssuer = "https://sts.windows.net/$($ENV:TenantId)/2.0"
            }
            validation   = @{
                allowedAudiences = "api://$($APIApp.appId)"
            }
        }
        $currentBody = ConvertTo-Json -Depth 15 -InputObject ($currentSettings | Select-Object Properties)
        
        Write-Host "writing to Azure"
        $SetAPIAuth = New-GraphPOSTRequest -type "PUT" -uri "https://management.azure.com/subscriptions/$($subscription)/resourceGroups/$ENV:ResourceGroupName/providers/Microsoft.Web/sites/$ENV:WEBSITE_SITE_NAME/Config/authsettingsV2?api-version=2018-11-01" -scope "https://management.azure.com/.default" -NoAuthCheck $true -body $currentBody
        Write-LogMessage -user $ExecutingUser -API $APINAME -tenant 'None '-message "Succesfully setup CIPP-API Access: $($_.Exception.Message)" -Sev "info"

        return @{
            ApplicationID     = $APIApp.AppId
            ApplicationSecret = $APIPassword.secretText
            Results           = "API Enabled. Your Application ID is $($APIApp.AppId) and your Application Secret is $($APIPassword.secretText)"
        }
    
    }
    catch {
        Write-LogMessage -user $ExecutingUser -API $APINAME -tenant 'None' -message "Failed to setup CIPP-API Access: $($_.Exception.Message)" -Sev "Error"
        return @{
            Results = " but could not set API configuration: $($_.Exception.Message)"
        }
        throw $return
    }
}