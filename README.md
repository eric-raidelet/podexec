# podexec
A shell tool to execute commands in one or multiple Pods / Containers in a Kubernetes environment.


The goal was to execute a command in multiple Pods / Containers at once, like getting
the disk free space df -h of all Containers for some reason.

The main usage comes in combination with the other tool named "checkpods" (see my repo), 
where you can filter Pods by specific criterias, get them in compact view mode and 
pass the output with xargs to podexec to run the given command in all of them.
