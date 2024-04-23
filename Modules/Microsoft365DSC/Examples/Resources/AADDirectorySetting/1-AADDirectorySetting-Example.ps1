<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
#>

Configuration Example
{
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credscredential
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        AADDirectorySetting 'Example'
        {
            Credential           = $Credscredential;
            DisplayName          = "Password Rule Settings";
            Ensure               = "Present";
            Id                   = "560ca84c-f568-4a11-9ad2-fede0829ea53";
            TemplateId           = "5cf42378-d67d-4f36-ba46-e8b86229381d";
            Values               = @(
                MSFT_MicrosoftGraphsettingValue{
                    Value = 'Audit'
                    Name = 'BannedPasswordCheckOnPremisesMode'
                }
                MSFT_MicrosoftGraphsettingValue{
                    Value = 'False'
                    Name = 'EnableBannedPasswordCheckOnPremises'
                }
                MSFT_MicrosoftGraphsettingValue{
                    Value = 'False'
                    Name = 'EnableBannedPasswordCheck'
                }
                MSFT_MicrosoftGraphsettingValue{
                    Value = '60'
                    Name = 'LockoutDurationInSeconds'
                }
                MSFT_MicrosoftGraphsettingValue{
                    Value = '10'
                    Name = 'LockoutThreshold'
                }
                MSFT_MicrosoftGraphsettingValue{
                    Value = 'bycn'
                    Name = 'BannedPasswordList'
                }
            );
        }
    }
}
