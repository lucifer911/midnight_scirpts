# LiveView.sh 
### Idea is based on CNTool's gLiveView
#### tested on ( Midnight Node Monitor - Testnet - Version: 0.8.0-cab67f3b )
LiveView.sh (version 0.1.2) is a simple script that allows users keep an eye on critical info. For now it tests
-  Node Version
-  Server Uptime
-  Container Start Time
-  Port
-  Network Blocks
-  Node Block
-  Peer Count
-  Hardware Resources
-  Produced Blocks Count

<img width="557" alt="enigma" src="https://github.com/user-attachments/assets/f34d4b23-b7e9-445c-aba0-d01348fa35a6" />



## Installation & Usage

To download and run LiveView.sh, follow these steps:

```bash
wget https://raw.githubusercontent.com/lucifer911/midnight_scirpts/main/LiveView.sh
sudo chmod +x LiveView.sh
./LiveView.sh
```
## User Variables
- If you change the Docker container name and port, make sure to update the corresponding variable in the script. By default, the script assumes the container name is:
```bash
midnight
port=9944
```

## NOTE
Docker logs are not persisted by default. If you restart the Docker container, all previous log entries are lost. As a result, the block count resets and will only reflect blocks minted after the restart.

## Troubleshoot
Another way to check if the script is working for you is to run the following curl command. If you see metric output, the setup is likely correct. Just be sure to update the user variables if you’re not using the default settings.
```bash
curl -s http://127.0.0.1:9615/metrics
```
## Contribut
Pull requests are welcome. 


