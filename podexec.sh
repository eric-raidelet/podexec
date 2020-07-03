#!/bin/bash
#
#
Version="1.0"
# v1.0 - June 24th 2020 - Eric Raidelet
# Initial Release
#



# Some defaults, you can change them

DefaultNameSpace="default" # If no namespace is given use this one


# console colors

color_white="\033[1;37m"
color_orange="\033[0;33m"
color_red="\033[0;31m"
color_green="\033[0;32m"
color_nc="\033[0m"


# No root, no cookies
if [ "$(id -u)" != "0" ]; then echo -e "\nThis script must run ${color_white}as uid=0 (root)${color_nc}\n"; exit 1; fi


usage()
{
	echo ""
	echo -e "${color_orange}podexec.sh v$Version - Eric Raidelet${color_nc}"
	echo "--------------------------------------------------------------------"
	echo "This tool is an extension to checkpods.sh to execute shell commands"
	echo "in one or multiple Pods. However, it can also be used standalone."
	echo "--------------------------------------------------------------------"
	echo ""
	echo "podexec.sh -r \"cat /etc/passwd\" mypod1 mypod2"
	echo ""
	echo -e "${color_orange}Usage:${color_nc}"
	echo "-p = Pod name, you can enter mutliple hosts."
	echo "     <PodName> Single Pod name"
	echo "     <\"PodName1 PodName2 PodName3\"> Multiple Pod names"                         
	echo "     Note: Multiple Pod must should be space delimited and"
	echo "     enclosed in quotes \"pod1 pod2 pod2\""
	echo "-c = Container name to use"
	echo "     <ContainerName>"
	echo "-n = Pod namespace. Default is \"default\""
	echo "-P = Pod Prefix. This will first run checkpods.sh to get a list"
	echo "     of Pods matching your Prefix (it will grep). This has"
	echo "     priority over -p -c options."
	echo "-r = Run the given command. Always enclose it in quotes."
	echo "-t = Run the command with kubectl exec -it (tty) mode enabled"
	echo "-q = Quiet mode, suppress some informational output"
	echo ""
	echo -e "${color_orange}Example:${color_nc}"
	echo "--------------------------------------------------------------------"
	echo "podexec.sh -r \"cat /var/log/system.log | grep something\" -p mypod1"
	echo "---> Show the system.log file and grep for something in mypod1"
	echo ""
	
	

	exit 0
}


# some variable defaults

PodName=""
PodList=""
PodPrefix=""
ContainerName=""
PodCommand=""
Silent="false"
IncludeArgs=""
ExcludeArgs=""
UseInteractiveMode="false"


while getopts "p:c:r:n:qg:e:P:t" OPTION
do
	
	case $OPTION in
		p)
		PodList=$OPTARG
		;;
		c)
		ContainerName=$OPTARG
		;;
		r)
		PodCommand=$OPTARG
		;;
		n)
		NameSpace=$OPTARG
		;;
		q)
		Silent="true"
		;;
		g)
		IncludeArgs=$OPTARG
		;;
		e)
		ExcludeArgs=$OPTARG
		;;
		P)
		PodPrefix=$OPTARG
		;;
		t)
		UseInteractiveMode="true"
		;;
		*)
		usage
		exit n | 1
		;;
	esac
done

# Get the last commandline argument as the PodList.
# Multiple Pods can be added but must be surrounded by quotes: "pod1 pod2 pod3"

shift $(($OPTIND - 1))
if [ $# -gt 0 ]; then PodList=$*; fi



# Splitting our Pods in an array to loop through later

if [ "$PodPrefix" != "" ] # The user wants a grep from checkpods.sh output, reset the PodList variable
then
	if [ ! -e "/usr/bin/checkpods.sh" ]
	then
		echo "/usr/bin/checkpods.sh is required to use this option, but not found."
		exit 1
	fi
	PodList=$(checkpods.sh -c p -s p | grep $PodPrefix)
	read -a PodArr <<< $PodList
else
	origIFS=$IFS
	IFS=" "
	read -a PodArr <<< $PodList
	IFS=$origIFS
fi

# setting no or nonsense input to defaults
if [ "$NameSpace" = "" ]; then NameSpace="$DefaultNameSpace"; fi
if [ "$UseInteractiveMode" = "true" ]
then
	UseInteractiveMode=" -it"
else
	UseInteractiveMode=""
fi

# If no command was given we can exit and show the help
if [ "$PodCommand" = "" ]; then	usage; fi


# If we still have no Pods to show logs for, show usage and skip
if [ "$PodList" = "" ]; then usage; fi




# Finally, lets execute the cmd line

for ThisPod in "${PodArr[@]}"
do

	# Grab a fresh set of values for the current Pod
	
	cmd="kubectl get pods --no-headers=true -n $NameSpace --field-selector=metadata.name=$ThisPod -o=custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name"
	Values=$(eval $cmd)
	if [ "$Values" = "" ]
	then
		echo "--------------------------------------------------------------------------------------"
		echo -e "${color_orange}No Pod found with name <$ThisPod> in namespace <$NameSpace>${color_nc}"
		echo "--------------------------------------------------------------------------------------"
		continue
	fi
	
	if [ "$ContainerName" = "" ]
	then
		Containers=$(echo $Values | awk '{print $2}')
	else
		Containers=$ContainerName
	fi
	
	# Some Pods have more than 1 Container, get them
	
	origIFS=$IFS
	IFS=","
	read -a ContainerArr <<< "$Containers"
	IFS=$origIFS
	
	# Loop through the Containers and execute the command
	
	for ThisContainer in "${ContainerArr[@]}"
	do
		if [ "$Silent" != "true" ]
		then
			echo "--------------------------------------------------------------------------------------"
			echo "Pod:       $ThisPod (Available Containers: $Containers)"
			echo "Container: $ThisContainer"
			echo "Command:   $PodCommand"
			echo "--------------------------------------------------------------------------------------"
		fi

		cmd="kubectl exec${UseInteractiveMode} -n ${NameSpace} ${ThisPod} -c ${ThisContainer} -- ${PodCommand}"
		#echo $cmd
		Values=$(eval $cmd)
		if [ "$Values" = "" ]
		then
			echo -e "${color_green}No result came back${color_nc}"
		else
			echo "$Values"
			echo ""
		fi

	done
	
done
