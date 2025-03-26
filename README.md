---

# Network Scanner Toolkit 🔍  

A modular **Shell Script** tool for network scanning and service detection. It performs **ping tests**, detects **NAT configuration**, resolves **hostnames**, and runs **Nmap scans** to identify active services. Designed for both learning and practical network analysis.  

---

## Project Structure 📂  

- **Port Scanning**: Detects open and filtered ports.  
- **Service Identification**: Determines running services on open ports.  
- **Ping Test**: Verifies host availability and response.  
- **NAT Detection**: Checks for differences between internal and external IPs.  
- **Hostname Resolution**: Uses **nslookup** for internal and external domains.  
- **Automated Report Generation**: Saves results as `scan-<IP>-<timestamp>.txt`.
- **OS Detection**: Identifies various operating systems (e.g., CentOS, Ubuntu, Windows 2012, VMware Photon, Windows 2008, Windows 2016, Alma Linux 9), with **special alerts** for CentOS.
- **Interactive Nmap Customization**: Optionally allows the user to adjust Nmap port ranges and flags before scanning.


---

## Objectives 🎯  

- Provide hands-on network security and analysis examples.  
- Create an extensible framework for network scanning.  
- Serve as an educational resource for security and sysadmin professionals.
- Allow flexible scanning modes: internal-only scanning or combined external/internal scanning for NAT comparison.

---

### Features:  

    Host availability check: 10.7.8.115 → Responds to ping  

    NAT detection: External 177.20.147.82 ≠ Internal 10.7.8.115  

    Service & OS Scanning:
    Open and filtered ports detected along with operating system fingerprinting. Special alert is provided       if CentOS is found (suggesting migration), while other OS detections are logged informatively.

    Interactive Configuration:
    The tool prompts the user for custom IP ranges and Nmap configurations, ensuring flexibility during          scans.

---

## Getting Started 🚀  

### 1. Clone Repository  

```bash
git clone https://github.com/devltz/Bash-RapidTrigger.git
cd Bash-RapidTrigger
```

### 2. Grant Execution Permission  

```bash
chmod +777 scan.sh
```

### 3. Run the Scanner  

```bash
./scan.sh 
```

> **Example:**  
> ```bash
> ./scan.sh
> If only an internal IP is provided, the tool runs a standalone scan (hostname resolution, ping, Nmap, and OS detection) without attempting external tests or NAT comparison.
> If both external and internal IPs are configured, the script performs additional NAT detection by comparing the IPs.


> ```

---

## Roadmap & Contributing 🛣️  

⚔️ Planned features:  

    - ✅ Port scanning  

    ▢ OS fingerprinting  

    ▢ Advanced service detection  

    ▢ Export results in JSON format  

---

## Contribution Guide 🧙‍♂️  

    - Fork repository  

    - Create a feature branch  

    - Add tests for new functionalities  

    - Submit a PR with documentation updates  

---

## Learning Resources 📚  

    > https://nmap.org/book/  
    > https://www.cybrary.it/course/network-security/  
    > https://linux.die.net/man/8/ping  

---

## License 📜  

**🌐 GPL3.0 License**  
**👨💻 Maintainer: [r3qu1em]**  

**📧 Contact: [kaua.dovale@proton.me](mailto:kaua.dovale@proton.me)**  

**🐛 Issue Tracker: GitHub Issues**  

🔍 Happy Scanning! More features coming soon...
