# LiveView.sh 
### Idea is based on CNTool's gLiveView
#### tested on ( Midnight Node Monitor - Testnet - Version: 0.8.0-cab67f3b )
LiveView.sh is a simple script that allows users keep an eye on critical info. For now it tests
-  Node Version
-  Server Uptime
-  Container Start Time
-  Node Key
-  Port
-  Network Blocks
-  Node Block
-  Peer Count
-  Hardware Resources
-  Produced Blocks Count

 <img width="524" alt="enigma_midnight" src="https://github.com/user-attachments/assets/0832ec21-f765-47c2-a524-f78d5b4147fa" />



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

## Contribut
Pull requests are welcome. 


