FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-22.04
# Update and install dependencies
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install build-essential -y
RUN apt-get install wget -y
# The P compiler is implemented in C# and hence the tool chain requires dotnet.
# P currently uses the specific version of .Net SDK 8.0.
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt install -y dotnet-sdk-8.0

# Verify .Net is installed
RUN dotnet --list-sdks

# The P compiler also requires Java Runtime (version 11 or higher).
RUN apt install -y default-jre

# Verify JRE is installed
RUN java -version