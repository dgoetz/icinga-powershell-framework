function Get-IcingaFrameworkServiceBinary()
{
    param(
        [string]$FrameworkServiceUrl,
        [string]$ServiceDirectory
    );

    $ProgressPreference = "SilentlyContinue";

    if ([string]::IsNullOrEmpty($FrameworkServiceUrl)) {
        if ((Get-IcingaAgentInstallerAnswerInput -Prompt 'Do you provide a custom source of the service binary?' -Default 'n').result -eq 1) {
            $LatestRelease       = (Invoke-WebRequest -Uri 'https://github.com/Icinga/icinga-powershell-service/releases/latest' -UseBasicParsing).BaseResponse.ResponseUri.AbsoluteUri;
            $FrameworkServiceUrl = $LatestRelease.Replace('/tag/', '/download/');
            $Tag                 = $FrameworkServiceUrl.Split('/')[-1];
            $FrameworkServiceUrl = [string]::Format('{0}/icinga-service-{1}.zip', $FrameworkServiceUrl, $Tag);
        } else {
            $FrameworkServiceUrl = (Get-IcingaAgentInstallerAnswerInput -Prompt 'Please enter the full path to your service binary repository' -Default 'v').answer;
        }
    }

    if ([string]::IsNullOrEmpty($FrameworkServiceUrl)) {
        Write-Host 'No Url to download the Icinga Service Binary from has been specified. Please try again.';
        return Get-IcingaFrameworkServiceBinary;
    }

    if ([string]::IsNullOrEmpty($ServiceDirectory)) {
        $ServiceDirectory = (Get-IcingaAgentInstallerAnswerInput -Prompt 'Please enter the path you wish to install the service to' -Default 'v' -DefaultInput 'C:\Program Files\icinga-framework-service\').answer;
    }

    if ((Test-Path $ServiceDirectory) -eq $FALSE) {
        New-Item -Path $ServiceDirectory -Force -ItemType Directory | Out-Null;
    }

    $TmpDirectory  = New-IcingaTemporaryDirectory;
    $ZipArchive    = Join-Path -Path $TmpDirectory -ChildPath ($FrameworkServiceUrl.Split('/')[-1]);
    $TmpServiceBin = Join-Path -Path $TmpDirectory -ChildPath 'icinga-service.exe';
    $UpdateBin     = Join-Path -Path $ServiceDirectory -ChildPath 'icinga-service.exe.update';
    $ServiceBin    = Join-Path -Path $ServiceDirectory -ChildPath 'icinga-service.exe';

    try {
        Invoke-WebRequest -Uri $FrameworkServiceUrl -UseBasicParsing -OutFile $ZipArchive;
    } catch {
        Write-Host ([string]::Format('Failed to download the Icinga Service Binary from "{0}". Please try again.', $FrameworkServiceUrl));
        return Get-IcingaFrameworkServiceBinary;
    }

    if ((Expand-IcingaZipArchive -Path $ZipArchive -Destination $TmpDirectory) -eq $FALSE) {
        throw 'Failed to expand the downloaded ZIP archive';
    }

    if ((Test-IcingaZipBinaryChecksum -Path $TmpServiceBin) -eq $FALSE) {
        throw 'The checksum of the downloaded file and the required MD5 hash are not matching';
    }

    Copy-ItemSecure -Path $TmpServiceBin -Destination $UpdateBin -Force | Out-Null;
    Start-Sleep -Seconds 1;
    Remove-ItemSecure -Path $TmpDirectory -Recurse -Force | Out-Null;

    return @{
        'FrameworkServiceUrl' = $FrameworkServiceUrl;
        'ServiceDirectory'    = $ServiceDirectory;
        'ServiceBin'          = $ServiceBin;
    };
}
