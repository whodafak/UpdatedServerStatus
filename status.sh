#!/bin/bash

normal=$(tput sgr0)
bold=$(tput bold)

PYTHON_CLIENT="https://raw.githubusercontent.com/whodafak/UpdatedServerStatus/main/sclient3.py"
PYTHONPSUTIL_CLIENT="https://raw.githubusercontent.com/whodafak/UpdatedServerStatus/main/sclient3bsd.py"

CWD=$(pwd)

command_exists () {
	type "$1" &> /dev/null ;
}

if ! command_exists curl; then
	echo "curl not found, install it."
	exit 1
fi

user_input ()
{
	args="${@:2}"
	while [ true ]; do
		answer=""
		printf "~> "

		if [ "$1" ]; then
			args="${@:1}"
			read answer
			if [ "$answer" == "" ]; then
				answer=$1
				echo -en "\033[1A\033[2K"
				echo "~> $1"
				break
			fi
		else
			while [ true ]; do
				read answer
				if [ "$answer" == "" ]; then
					echo "${bold}Invalid input!${normal}"
					printf "~> "
				else
					break
				fi
			done
		fi

		if [ "$2" ]; then
			for arg in $args; do
				if [ "$arg" == "_NUM" ] && [ "${answer##*[!0-9]*}" ]; then
					break 2
				elif [ "${arg,,}" == "${answer,,}" ]; then
					break 2
				fi
			done
			echo "${bold}Invalid input!${normal}"
		else
			break
		fi
	done
}

echo
echo "ServerStatus Client Setup Script"
echo "https://github.com/BotoX/ServerStatus"
echo

echo "Which client implementation do you want to use? [${bold}python${normal}, python-psutil,]"
user_input "python" "python-psutil"
CLIENT="${answer,,}"

if [ "$CLIENT" == "python" ] && [ -f "${CWD}/client.py" ]; then
	echo "Python implementation already found in ${CWD}"
	echo "Do you want to skip the client configuration and update it? [${bold}yes${normal}/no]"
	user_input "yes" "no" "y" "n"
	if [ "${answer,,}" == "yes" ] || [ "${answer,,}" == "y" ]; then
		CLIENT_BIN="${CWD}/client.py"
		SKIP=true
	fi
elif [ "$CLIENT" == "python-psutil" ] && [ -f "${CWD}/client-psutil.py" ]; then
	echo "Python-psutil implementation already found in ${CWD}"
	echo "Do you want to skip the client configuration and update it? [${bold}yes${normal}/no]"
	user_input "yes" "no" "y" "n"
	if [ "${answer,,}" == "yes" ] || [ "${answer,,}" == "y" ]; then
		CLIENT_BIN="${CWD}/clientbsd.py"
		SKIP=true
	fi
fi

if [ ! $SKIP ]; then
	echo "What is your status servers address (${bold}DNS${normal} or IP)?"
	user_input
	SERVER="$answer"

	echo "What is your status servers port? [${bold}35601${normal},...]"
	user_input 35601 _NUM
	PORT="$answer"

	echo "Specify the username."
	user_input
	USERNAME="$answer"

	echo "Specify a password for the user."
	user_input
	PASSWORD="$answer"
else
	DATA=$(head -n 9 "$CLIENT_BIN")

	SERVER=$(echo "$DATA" | sed -n "s/SERVER\( \|\)=\( \|\)//p" | tr -d '"')
	PORT=$(echo "$DATA" | sed -n "s/PORT\( \|\)=\( \|\)//p" | tr -d '"')
	USERNAME=$(echo "$DATA" | sed -n "s/USER\( \|\)=\( \|\)//p" | tr -d '"')
	PASSWORD=$(echo "$DATA" | sed -n "s/PASSWORD\( \|\)=\( \|\)//p" | tr -d '"')
fi

echo
echo "${bold}Summarized settings:${normal}"
echo
echo -e "Client implementation:\t${bold}$CLIENT${normal}"
echo -e "Status server address:\t${bold}$SERVER${normal}"
echo -e "Status server port:\t${bold}$PORT${normal}"
echo -e "Username:\t\t${bold}$USERNAME${normal}"
echo -e "Password:\t\t${bold}$PASSWORD${normal}"
echo

echo "Is this correct? [${bold}yes${normal}/no]"
user_input "yes" "no" "y" "n"

if [ "${answer,,}" != "yes" ] && [ "${answer,,}" != "y" ]; then
	echo "Aborting."
	echo "You may want to rerun this script."
	exit 1
fi

if [ "$CLIENT" == "python" ]; then
	echo "Magic going on..."
	curl -L "$PYTHON_CLIENT" | sed -e "0,/^SERVER = .*$/s//SERVER = \"${SERVER}\"/" \
		-e "0,/^PORT = .*$/s//PORT = ${PORT}/" \
		-e "0,/^USER = .*$/s//USER = \"${USERNAME}\"/" \
		-e "0,/^PASSWORD = .*$/s//PASSWORD = \"${PASSWORD}\"/" > "${CWD}/client.py"
	chmod +x "${CWD}/client.py"
	CLIENT_BIN="${CWD}/client.py"
	echo
	echo "Python client copied to ${CWD}/client.py"

elif [ "$CLIENT" == "python-psutil" ]; then
	echo "Magic going on..."
	curl -L "$PYTHONPSUTIL_CLIENT" | sed -e "0,/^SERVER = .*$/s//SERVER = \"${SERVER}\"/" \
		-e "0,/^PORT = .*$/s//PORT = ${PORT}/" \
		-e "0,/^USER = .*$/s//USER = \"${USERNAME}\"/" \
		-e "0,/^PASSWORD = .*$/s//PASSWORD = \"${PASSWORD}\"/" > "${CWD}/client-psutil.py"
	chmod +x "${CWD}/clientbsd.py"
	CLIENT_BIN="${CWD}/clientbsd.py"
	echo
	echo "Python-psutil client copied to ${CWD}/clientbsd.py"
fi

if [ ! $SKIP ]; then
	echo
	echo "In case you haven't already added the new client to the master server:"
	echo

	echo -e "\t\t{"
	echo -e "\t\t\t\"name\": \"Change me\","
	echo -e "\t\t\t\"type\": \"Change me\","
	echo -e "\t\t\t\"host\": \"Change me\","
	echo -e "\t\t\t\"location\": \"Change me\","
	echo -e "\t\t\t\"username\": \"$USERNAME\","
	echo -e "\t\t\t\"password\": \"$PASSWORD\","
	echo -e "\t\t},"
fi

echo
echo "Have fun."
echo

exit 0
