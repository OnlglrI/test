# download_deps.ps1
# Downloads ALL Maven and NuGet dependencies into libs\ folder.
# Does NOT require S3/S4/S5/S6 project folders to exist.
# After running this script, internet is no longer needed for builds.
#
# Offline build:
#   mvn package -o -Dmaven.repo.local=..\..\libs\maven -DskipTests
#   dotnet restore --packages ..\..\libs\nuget && dotnet build --no-restore
#
# Usage: .\download_deps.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibsMaven = "$ScriptDir\libs\maven"
$LibsNuget = "$ScriptDir\libs\nuget"
$TempDir   = "$ScriptDir\_tmp_deps"

function Write-Info ($msg) { Write-Host "[INFO] $msg" -ForegroundColor Green  }
function Write-Warn ($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err  ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# --- Check tools ---
if (-not (Get-Command mvn    -ErrorAction SilentlyContinue)) { Write-Err  "Maven not found. Install from https://maven.apache.org/" }
if (-not (Get-Command java   -ErrorAction SilentlyContinue)) { Write-Err  "Java not found. Install JDK 17+" }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Write-Warn "dotnet not found - NuGet deps will be skipped" }

# --- Create folders ---
Write-Info "Creating libs\maven and libs\nuget..."
New-Item -ItemType Directory -Force -Path $LibsMaven | Out-Null
New-Item -ItemType Directory -Force -Path $LibsNuget  | Out-Null
New-Item -ItemType Directory -Force -Path $TempDir    | Out-Null

# ===========================================================================
#  MAVEN
#  Strategy: create a single temp pom.xml with ALL project dependencies,
#  then run "mvn package -DskipTests" which downloads every transitive jar.
#  dependency:go-offline is NOT used - it misses transitive dependencies.
# ===========================================================================

Write-Info "Creating temp pom.xml with all dependencies..."

$PomContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.3</version>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>deps-downloader</artifactId>
    <version>1.0.0</version>

    <properties>
        <java.version>17</java.version>
        <jjwt.version>0.12.3</jjwt.version>
    </properties>

    <dependencies>
        <!-- S3/S5/S6: Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <!-- S3/S5/S6: JPA -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <!-- S3/S5/S6: Validation -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <!-- S3/S5/S6: MySQL -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <scope>runtime</scope>
        </dependency>
        <!-- S3/S5/S6: Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <!-- S5/S6: Security -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <!-- S3/S5/S6: MSSQL -->
        <dependency>
            <groupId>com.microsoft.sqlserver</groupId>
            <artifactId>mssql-jdbc</artifactId>
            <version>12.4.2.jre11</version>
            <scope>runtime</scope>
        </dependency>
        <!-- S5/S6: JJWT -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.11.5</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.11.5</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.11.5</version>
            <scope>runtime</scope>
        </dependency>
        <!-- S6: Tests -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <skip>true</skip>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
'@

$TempPomDir = "$TempDir\maven_temp"
New-Item -ItemType Directory -Force -Path $TempPomDir | Out-Null
[System.IO.File]::WriteAllText("$TempPomDir\pom.xml", $PomContent, [System.Text.Encoding]::UTF8)

Write-Info "Downloading Maven dependencies (Spring Boot 3.2.3 + JJWT 0.12.3)..."
mvn -f "$TempPomDir\pom.xml" `
    package `
    "-Dmaven.repo.local=$LibsMaven" `
    -DskipTests `
    --no-transfer-progress

if ($LASTEXITCODE -ne 0) {
    Write-Warn "Maven finished with error (code $LASTEXITCODE)"
} else {
    Write-Info "Maven dependencies downloaded successfully"
}

# ===========================================================================
#  NUGET
# ===========================================================================

if (Get-Command dotnet -ErrorAction SilentlyContinue) {

    Write-Info "Creating temp .csproj for net8.0-windows..."

    $CsprojContent = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <UseWindowsForms>true</UseWindowsForms>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
  </PropertyGroup>
  <ItemGroup>
    <!-- S4/S5/S6 desk: JSON serialization -->
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>
</Project>
'@

    $TempCsprojDir = "$TempDir\nuget_temp"
    New-Item -ItemType Directory -Force -Path $TempCsprojDir | Out-Null
    [System.IO.File]::WriteAllText("$TempCsprojDir\TempApp.csproj", $CsprojContent, [System.Text.Encoding]::UTF8)

    Write-Info "Downloading NuGet dependencies (net8.0-windows)..."
    dotnet restore "$TempCsprojDir\TempApp.csproj" --packages $LibsNuget

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "dotnet restore finished with error (code $LASTEXITCODE)"
    } else {
        Write-Info "NuGet dependencies downloaded successfully"
    }

} else {
    Write-Warn "dotnet not found - NuGet dependencies skipped"
}

# --- Cleanup ---
Write-Info "Removing temp files..."
Remove-Item -Recurse -Force -Path $TempDir

# --- Summary ---
$MavenSize = if (Test-Path $LibsMaven) { "{0:N0} MB" -f ((Get-ChildItem $LibsMaven -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) } else { "0 MB" }
$NugetSize  = if (Test-Path $LibsNuget)  { "{0:N0} MB" -f ((Get-ChildItem $LibsNuget  -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) } else { "0 MB" }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Done!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  libs\maven\  - $MavenSize"
Write-Host "  libs\nuget\  - $NugetSize"
Write-Host ""
Write-Host "  Offline Maven build:"
Write-Host "    cd S3_plan\S3_SpringServer"
Write-Host "    mvn package -o -Dmaven.repo.local=..\..\libs\maven -DskipTests"
Write-Host ""
Write-Host "  Offline NuGet build:"
Write-Host "    cd S4_plan\S4_Client"
Write-Host "    dotnet restore --packages ..\..\libs\nuget"
Write-Host "    dotnet build --no-restore"
Write-Host ""
