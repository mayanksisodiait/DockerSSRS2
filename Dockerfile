FROM mcr.microsoft.com/windows/servercore:ltsc2019

LABEL maintainer "Mayank Sisodia"

# SQL Server 2016 vNext:
ENV exe "https://go.microsoft.com/fwlink/?linkid=835677"
ENV box "https://go.microsoft.com/fwlink/?linkid=835679"

ENV sa_password="Test@123" \
    attach_dbs="" \
    ACCEPT_EULA="Y" \
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password" \
    ssrs_user="SSRSAdmin" \
    ssrs_password="Test@123" \
    SSRS_edition="EVAL" \
    ssrs_password_path="C:\ProgramData\Docker\secrets\ssrs-password"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# make install files accesssible
COPY start.ps1 /
COPY configureSSRS2017.ps1 /
COPY sqlstart.ps1 /
COPY newadmin.ps1 /
WORKDIR /

RUN    Invoke-WebRequest -Uri "https://download.microsoft.com/download/E/6/4/E6477A2A-9B58-40F7-8AD6-62BB8491EA78/SQLServerReportingServices.exe" -OutFile SQLServerReportingServices.exe ; \
Start-Process -Wait -FilePath .\SQLServerReportingServices.exe -ArgumentList "/quiet", "/norestart", "/IAcceptLicenseTerms", "/Edition=$env:SSRS_edition" -PassThru -Verbose

RUN  Invoke-WebRequest -Uri $env:box -OutFile SQL.box ; \
        Invoke-WebRequest -Uri $env:exe -OutFile SQL.exe ; \
	Start-Process -Wait -FilePath .\SQL.exe -ArgumentList /qs, /x:setup ; \
        .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ; \
        Remove-Item -Recurse -Force SQL.exe, SQL.box, setup

RUN stop-service MSSQLSERVER ; \
        set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.MSSQLSERVER\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
        set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.MSSQLSERVER\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433 ; \
        set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.MSSQLSERVER\mssqlserver\' -name LoginMode -value 2 ;

HEALTHCHECK CMD [ "sqlcmd", "-Q", "select 1" ]

CMD .\start -sa_password $env:sa_password -ACCEPT_EULA $env:ACCEPT_EULA -attach_dbs \"$env:attach_dbs\" -ssrs_user $env:ssrs_user -ssrs_password $env:ssrs_password -Verbose
