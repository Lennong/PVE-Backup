# PVE-Backup

A bit of code to control which VM's in ProxMox (PVE) that should be shut down and not while backing up the PVE itself to ProxMox Backup Server (PBS). I am doing backups of the PVE installation to PBS but I prefer to shut down some of my virtual machines when collecting the backup as I have some databases I prefer not be touched by the VM's while taking the backup. 
