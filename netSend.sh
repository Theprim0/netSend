#!/bin/bash

##########################################################################################
#											 #
# Programa para copiar un directorio a varios sistemas remotos.				 #
# Este programa basicamente copia un fichero o directorio a una o varias maquinas	 #
# remotas. Si están apagadas, o no soportan rsync(windows), o la ip está mal puesta, te  #
# dirá cual es el problema en cada caso. (ejercicio propuesto en clase de ASIR)		 #
#											 #
# Por cada maquina a enviar, si es necesario, se irá pidiendo la clave para su acceso.   #
#											 #
# Cualquier error...¡reportar! https://github.com/Theprim0				 #
#											 #
##########################################################################################

# Colores
RED=$'\e[0;31m'
NC=$'\e[0m'
VERDE=$'\e[0;32m'
unset nombre_comprimido
unset nombre_total
estado=1

echo ' _   _      _          _____                _ '
echo '| \ | |    | |        / ____|              | |'
echo '|  \| | ___| |_ _____| (___   ___ _ __   __| |'
echo '| . ` |/ _ \ __|______\___ \ / _ \ \_ \ / _` |'
echo '| |\  |  __/ |_       ____) |  __/ | | | (_| |'
echo '|_| \_|\___|\__|     |_____/ \___|_| |_|\__,_|  ...by arturo'
echo

if ! hash rsync 2>/dev/null; then
	read -p "Para proceder debe instalarse rsync, ¿proceder? [s/n]: " instalar_opc
	if ! [[ $instalar_opc = s ]]; then
		echo "Saliendo..."
		exit 1
	else
		apt install rsync -y
	fi
fi

read -p "Inserte el directorio o fichero que se desea copiar al remoto: " directorio

if ! [[ -d $directorio ]] && ! [[ -f $directorio ]]; then
	echo "${RED}[FAIL]${NC} Copia FALLIDA, revise si existe el directorio a copiar..."
	exit 1
fi

read -p "¿Desea comprimirlo? [s/n]: " comprimir

if [[ $comprimir == s ]]; then
	nombre_comprimido=$( basename $directorio )\_$( date +%Y-%m-%d_%H_%M_%S ).tar.gz
	a_comprimir=$(tar -czvf /tmp/$nombre_comprimido $directorio &>/dev/null &)
	$a_comprimir &
	pid_proceso=$!
	while [ $estado = 1 ]; do
		for letritas in \| \/ \- \\ \| \/ \- \\; do
			echo -n -e "$letritas Comprimiendo.... \r"
			sleep 0.5
		done
		if ! [[ `echo $(ps aux | grep $pid_proceso | cut -d" " -f 11)` == "tar" ]]; then
			estado=0	
		fi
	done
#	wait $pid_proceso

	echo -n "  Comprimiendo.... ${VERDE}[HECHO]${NC}" 
	echo
	nombre_total="/tmp/$nombre_comprimido"
elif [[ $comprimir == n ]]; then
	:
else
	echo "VALOR INVÁLIDO"
	exit 1
fi

read -p "A cuantas máquinas va a enviar: " cantidad

for (( i=0 ; i<cantidad ; i++ )); do
	let numero=i+1
	read -p "Inserte la ip de la maquina $numero a enviar: " direccion
	mi_array_direcciones[$i]=$direccion
	maquina[$i]=`echo ${mi_array_direcciones[$i]}`
done

read -p "Inserte el usuario de las maquinas remotas: " usuario

#echo "#######################"
echo "## Comenzando copias ##"
#echo "#######################"

for (( i=0 ; i<cantidad ; i++ )); do
	if [[ `echo ${mi_array_direcciones[$i]}` =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		ping -w 1 ${mi_array_direcciones[$i]} &>/dev/null

		if [[ $? == 0 ]]; then
			rsync -a ${nombre_total:-$directorio} $usuario@${mi_array_direcciones[$i]}:~ &>/dev/null
			if [[ $? > 0 ]]; then
				echo "${RED}[FAIL]${NC} Máquina ${maquina[$i]} NO COMPATIBLE, saltando..."
			else
				echo "${VERDE}[OK]${NC} Copiado a la máquina ${maquina[$i]} EXITOSO"
			fi
			
		else
			echo "${RED}[FAIL]${NC} Máquina ${maquina[$i]} DOWN, saltando..."
		fi
	else
		echo "${RED}[FAIL]${NC} Dirección ${maquina[$i]} no válida, saltando..."
	fi
done


if [[ $comprimir == s ]]; then
	rm $nombre_total
fi
