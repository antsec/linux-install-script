#!/bin/bash

#Folders
local_content_folder=customer_data
certificates_folder=certificates
configs_folder=configs
packages_folder=packages
ssl_folder="/etc/ssl/as-collectors"
current_version="7.17.1"
current_dir=`pwd`

#Check permissions
if [ "$EUID" -ne 0 ]
  then echo "Please run the script as root"
  exit
fi

if [[ "$#" == 0 ]]
then
    echo "No parameters given, please provide at least -i(nstall) or -u(ninstall)"
    exit 1
fi

print_help()
{
    echo '
        -c|--customerid     Provide the customer id for the machine
        -H|--host           Provide the host to send data to
        -i|--install        Install or Update the collectors
        -u|--uninstall      Remove the installed collectors
        -t|--installer-type If the OS is not recognized specify the package manager manually [rpm,dpkg]
        -a|--all            Automatically install all collectors
        -b|--startonboot    Predetermine that autostart should be enabled
        -r|--reinstall      Predetermine that packages should be reinstalled
        -s|--skip-install   Predetermine to skip installs
        -O|--overwrite      Predetermine to overwrite configuration files
        -S|--skip           Predetermine to skip configuration file overwrites
        '
}

#Handle input parameters
while [[ "$#" > 0 ]]
do 
    echo "checking: $1"
    declare -A inputparms
    case $1 in
        -c|--customerid) inputparms['customer_id']="$2"; shift;;
        -H|--host) inputparms['host']="$2"; shift;;
        -i|--install) install=1;;
        -u|--uninstall) uninstall=1;;
        -t|--installer-type) inputparms['installer_type']="$2"; shift;;
        -a|--all) inputparms['select_collector']="a";;
        -b|--startonboot) inputparms['enable_autostart']="y";;
        -r|--reinstall) inputparms['package_setup_choice']="r";;
        -s|--skip-install) inputparms['package_setup_choice']="s";;
        -O|--overwrite) inputparms['overwrite_config']="o";;
        -S|--skip) inputparms['overwrite_config']="s";;
        -h|--help) print_help;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
    esac 
    shift
done

#Error handler
error_handler()
{
    if [ "$?" != "0" ]; then
        echo "$1"
        exit
    fi
}

read_question()
{
    question=$1
    silent_parm=$2
    #empty validation on every question read
    validation=''
    validation=$3
    answer=""

    #Check if the silent parm is empty
    if [ -z ${inputparms[$silent_parm]} ]
    then
        read -p "$question" answer
        #If there was any answer proceed
        if ([ -n "$answer" ])
        then
            #Check if a validation pattern is present and validate if so
            if [ -z "$validation" ] || [[ "$answer" =~ $validation ]]
            then
                return
            else
                echo "The question was not answered correctly, as the input did not match. Please try again.."
                read_question "$question" "$silent_parm" "$validation"
            fi
            return
        else
            echo "The question was not answered. Please try again.."
            read_question "$question" "$silent_parm" "$validation"
        fi
    else
        answer=${inputparms[$2]}
        #If there was any answer proceed
        if ([ -n "$answer" ])
        then
            #Check if a validation pattern is present and validate if so
            if [ -z "$validation" ] || [[ "$answer" =~ $validation ]]
            then
                return
            else
                echo "The parameter given for $silent_parm was not correct, as the input did not match. Exiting.."
                exit
            fi
            return
        else
            echo "The parameter given for $silent_parm was not provided. Please try again.."
            exit
        fi
    fi
}

#Check if configuration file exists
copy_item()
{
    source=$1
    destination=$2
    
    #If it is a directory, loop through all files and resend them through the function as files
    if [ -d $source ]
    then
        echo "Looping through files in $source"
        directory=$destination
        for file in $(find $source -mindepth 1)
        do 
            echo "Found file $file"
            #Grab file name
            file_name=`basename $file`
            copy_item $file $directory/$file_name
        done
        return
    fi

    if [ -f $destination ] 
    then
        #If so, ask to overwrite, create a new file or skip the copy
        read_question "The target $destination already exists, What do you want to do? [O]verwrite, [K]eep both, or [S]kip: " "overwrite_config"
        config_choice="$answer"
        if [[ $config_choice =~ o|O ]]
        then
            echo "Overwriting $destination"
            if [ -f $destination ]
            then
                echo "Creating bak file for $destination"
                cp -rf $destination $destination.bak
            fi
            cp -rf $source $destination
            sed -i -e "s/<customer_id>/$customer_id/g" $destination
            sed -i -e "s/<host>/$host/g" $destination
        elif [[ $config_choice =~ k|K ]]
        then
            echo "Copying file to $destination.new"
            cp -rf $source $destination.new
            sed -i -e "s/<customer_id>/$customer_id/g" $destination
            sed -i -e "s/<host>/$host/g" $destination
        elif [[ $config_choice =~ s|S ]]
        then
            echo "Skipping $source"
        else
            echo "An invalid option was provided, please try again"
            copy_item $source $destination
        fi
    else
        echo "Copying $source to $destination"
       cp -rf $source $destination
       sed -i -e "s/<customer_id>/$customer_id/g" $destination
       sed -i -e "s/<host>/$host/g" $destination
    fi
}

check_package() {
    echo "checking if required version is present"
    #cd $packages_folder
    ls $package-$current_version-$file_extention
    if [ $? -ne 0 ]
    then
        echo "Downloading version $current_version for $package"
        wget https://artifacts.elastic.co/downloads/beats/$package/$package-$current_version-$file_extention
        error_handler "Could not download file"
        #latest_version=`ls -lhS *.rpm | head -n 1 | awk '{print $9}'`
    fi
    echo "Checking package integrity, downloading sha 512 checksum from Elastic..."
    rm -f $package-$current_version-$file_extention.sha512
    wget https://artifacts.elastic.co/downloads/beats/$package/$package-$current_version-$file_extention.sha512
    shasum -c $package-$current_version-$file_extention.sha512
    error_handler "There was a checksum mismatch for $package. Please determine if this is a configuration or a possible security issue"
    #cd $current_dir
}

install_package()
{
    package=$1
    package_installed=false
    cd $current_dir/$packages_folder
    #Check if package is already installed
    if [ "$installer" == "dpkg" ]; then dpkg -l $package &> /dev/null
    elif [ "$installer" == "rpm" ]; then yum list $package &> /dev/null; fi
    
    if [ $? -eq 0 ]
    then
        #If installed, ask to reinstall or skip
        read_question "$package is already installed, What do you want to do? [R]einstall, [U]pgrade or [S]kip: " "package_setup_choice"
        package_setup_choice="$answer"
        if [[ $package_setup_choice =~ r|R ]]
        then
            echo "Reinstalling $package with $installer"
            check_package
            if [ "$installer" == "dpkg" ]; then dpkg -r $package
            elif [ "$installer" == "rpm" ]; then yum erase $package -y -q; fi
            error_handler "Could not remove $package"
            
            if [ "$installer" == "dpkg" ]; then dpkg -i $package-$current_version-$file_extention
            elif [ "$installer" == "rpm" ]; then rpm -i $package-$current_version-$file_extention; fi
            error_handler "Could not install $package"

            package_installed=true
        elif [[ $package_setup_choice =~ s|S ]]
        then
            echo "Skipping the installation of $package"
        elif [[ $package_setup_choice =~ u|U ]]
        then
            upgrade_package
        else
            echo "An invalid option was provided, please try again"
            install_package $package
        fi
    else
        echo "Installing $package with $installer"
        check_package
        if [ "$installer" == "dpkg" ]; then dpkg -i $package-$current_version-$file_extention
        elif [ "$installer" == "rpm" ]; then rpm -i $package-$current_version-$file_extention; fi
        error_handler "Could not install $package package"

        package_installed=true
    fi
    cd $current_dir

    #Check config files to see if they are the default configs. If so, delete them
    if [ "$package_installed" == true ] && [ -f /etc/$package/$package.yml ]
    then
        echo "Checking if default configuration is present after installation"
        if [ -f /etc/$package/$package.reference.yml ]
        then
            if [ `date -r /etc/$package/$package.yml +%s` == `date -r /etc/$package/$package.reference.yml +%s` ]
            then
                rm -f /etc/$package/$package.yml
                error_handler "Could not remove /etc/$package/$package.yml"
                # if [ "$package" == "filebeat" ]
                # then
                #     rm -f /etc/$package/modules.d/*
                #     error_handler "Could not remove files in /etc/$package/modules.d"
                # fi
            fi
        fi
    fi
}
upgrade_package()
{
    echo "Upgrading $package with $installer to $current_version"
    check_package
    if [ `$package version | awk '{print $3}'` != $current_version ]
    then
        if [ "$installer" == "dpkg" ]; then dpkg -i $package-$current_version-$file_extention
        elif [ "$installer" == "rpm" ]; then rpm -U $package-$current_version-$file_extention; fi
        error_handler "Could not install $package package"
        echo "restarting $package"
        systemctl restart $package
    else
        echo "The version is equal, no upgrade required"
    fi
}

start_on_boot()
{
    package=$1
    echo "Enabling $package..."
    if [ "$installer" == "dpkg" ]
    then
        systemctl enable $package
        error_handler "Could not configure $package to start on boot"
    elif [ "$installer" == "rpm" ]
    then
        chkconfig $service on
        error_handler "Could not configure $package to start on boot"
    fi
}

start_now()
{
    package=$1

    if [ "$installer" == "dpkg" ]
    then
        echo "starting $package..."
        systemctl start $package
        error_handler "Could not start $package"
    elif [ "$installer" == "rpm" ]
    then
        service $service start
        error_handler "Could not get $package to start, check the configuration manually"
    fi
}
uninstall_package()
{
    package=$1
    package_installed=false
    #Check if package is already installed
    if [ "$installer" == "dpkg" ]; then dpkg -l $package &> /dev/null
    elif [ "$installer" == "rpm" ]; then yum list $package &> /dev/null; fi
    
    if [ $? -eq 0 ]
    then
        echo "Uninstalling $package"
        if [ "$installer" == "dpkg" ]; then dpkg -P $package
        elif [ "$installer" == "rpm" ]; then yum erase $package -y -q; fi
        error_handler "Could not uninstall $package"
    else
        echo "$package was not found on the system"
    fi
}

################### Prerequisites ###################

#Check the OS on which the collectors are going to be installed
if [ -f /etc/debian_version ]
then
    os_version=`cat /etc/debian_version`
    installer="dpkg"
    file_extention="amd64.deb"
fi

if [ -f /etc/redhat-release ]
then
    os_version=`cat /etc/redhat-release`
    installer="rpm"
    os="redhat"
    file_extention="x86_64.rpm"
fi

if [ -f /etc/centos-release ]
then
    os_version=`cat /etc/centos-release`
    installer="rpm"
    os="centos"
    file_extention="x86_64.rpm"
fi

#If Debian / Ubuntu, RedHat / Centos continue the installation otherwise ask to provide installer type
if [ -z $installer ]
then
    echo "No supported OS was found"
    #If not recognized, prompt option to choose for DPKG or RPM install on own risk, or exit
    read_question "If you want to try manually, please enter 'dpkg' or 'rpm'" "installer_type"
    installer="$answer"
fi

#Check if an installer type has been found and is an expected value
if [[ $installer =~ dpkg|rpm ]]
then
    echo "A valid installer type has been provided"
else
    echo "There was no valid installer type found, exiting"
    exit 1
fi

#Ask for API key that was provided when adding the machine on the dashboard
#Disabled until API is present
if [ $install ]
then
    #Ask for the customer_id
    read_question "What is your customer ID?: " "customer_id" 'as[0-9]{11}'
    customer_id=$answer
    
    #Ask for the host
    read_question "Provide the host to send data to: " "host"
    host=$answer
    
    #Ask which packages the user would like to install
    supported_collectors=(filebeat packetbeat auditbeat metricbeat)
    counter=-
    for i in ${!supported_collectors[@]} ; do
    echo "$i: ${supported_collectors[$i]}"
    let counter=$counter+1
    done
    echo "Select a to enable all collectors"

    #Input customer name for folder definition
    read_question "Select a collector from the list to mark it for install (type a number from the list and press enter): " "select_collector"
    select_collector=$answer
    #collector_install_list=""
    while true
    do
        if [[ $select_collector =~ a|A ]]
        then
            collector_install_list=("filebeat" "packetbeat" "auditbeat" "metricbeat")
            break
        elif [ ${collector_install_list[$select_collector]+exists} ]
        then
            echo "Collector is already added to the list"
        else
            if [ ${supported_collectors[$select_collector]+exists} ]
            then
                echo "Adding collector to the list" 
                collector_install_list[$select_collector]=${supported_collectors[$select_collector]}
                select_collector=""
            else
                echo "You have selected an invalid option"
            fi
        fi
        read -p "Optionally select another collector, otherwise press Enter: " select_collector
        
        if [ -z "$select_collector" ]
        then
            break
        fi
    done

    echo "You have selected: ${collector_install_list[@]}"

    #Check $local_content_folder for local content
    if [ -d $local_content_folder ]
    then
        if [ -d $certificates_folder ]
        then
            echo "Locally present certificates found, using these..."
            certificates_local=true
            #TO DO: Validate certificates present
        fi
        if [ -d $packages_folder ]
        then
            echo "Locally present collector packages found, using these..."
            collectors_local=true
            #TO DO: Validate certificates present
        fi
        if [ -d $configs_folder ]
        then
            echo "Locally present configs found, using these..."
            collectors_local=true
            #TO DO: Validate certificates present
        fi
    fi

    #Download packages based upon install type (dpkg or rpm)
    if [ "$certificates_local" == false ]
    then
        echo "No local certificates found, downloading is not yet supported. Exiting..."
        exit
    fi
    #Download certificates from AntSec with API key
    if [ "$collectors_local" == false ]
    then
        echo "No local collector packages found, downloading is not yet supported. Exiting..."
        exit
    fi

    #Download configuration from AntSec with API key
    if [ "$config_local" == false ]
    then
        echo "No local config found, downloading is not yet supported. Exiting..."
        exit
    fi

    ################### Install Phase ###################

    #Check if $ssl_folder exists
    if [ ! -d $ssl_folder ]
    then 
        mkdir $ssl_folder
        error_handler "Could not create folder"
    fi

    #Check if certificates are already present
    #if [ -f $ssl_folder ]

    #Check if certificates are different than the ones that should be

    #If present, ask to overwrite

    #Extract certificates to the required location
    cp $certificates_folder/* $ssl_folder/
    error_handler "Could not copy certificate files"

    #Install the selected packages    
    for collector in "${collector_install_list[@]}"
    do
        install_package $collector
    done

    #Copy the configuration to the /etc folders

    for collector in "${collector_install_list[@]}"
    do
        #Check if configuration folder exists
        if [ ! -d "/etc/$collector" ]
        then 
            error_handler "$collector package is not installed correctly"
        else
            # Loop through files to check if they exists and ask what to do with them
            #/etc/$collector/$collector.yml
            #$configs_folder/$collector.yml
            copy_item $configs_folder/$collector/$collector.yml /etc/$collector/$collector.yml
            if [ "$collector" == "filebeat" ]
            then
                copy_item $configs_folder/$collector/modules.d /etc/$collector/modules.d
            fi
        fi
    done
    #Set all required permissions
    echo "Checking permissions on the private key(s)"
    for key in `ls $ssl_folder/*.key`
    do
        if chmod 600 $key
        then
            echo "Changed permission of $key to 600"
        fi
    done

    echo "The AntSec Collectors have been successfully installed"

    read_question "Would you like to automatically start the services upon boot? [Y/n]: " "enable_autostart"
    enable_autostart="$answer"

    if [[ $enable_autostart =~ y|Y ]]
    then
        for collector in "${collector_install_list[@]}"
        do
            start_on_boot $collector
        done
    else
        echo "Did not receive 'yes', skipping autostart configuration for $package"
    fi

    read -p "Would you like to start the services now? [Y/n]: " -i "Y" -e start_services
    
    if [[ $start_services =~ y|Y ]]
    then
        for collector in "${collector_install_list[@]}"
        do
            start_now $collector
        done
    else
        echo "Did not receive 'yes', skipping autostart configuration for $package"
    fi
    exit

elif [ $uninstall ]
then
    #Ask which packages the user would like to install
    supported_collectors=(filebeat packetbeat auditbeat metricbeat)
    counter=-
    for i in ${!supported_collectors[@]} ; do
    echo "$i: ${supported_collectors[$i]}"
    let counter=$counter+1
    done
    echo "Select 'a' to uninstall all collectors"

    #Input customer name for folder definition
    read_question "Select a collector from the list to mark it for uninstall (type a number from the list and press enter): " "select_collector"
    select_collector="$answer"

    #collector_install_list=""
    while true
    do
        if [[ $select_collector =~ a|A ]]
        then
            collector_install_list=("filebeat" "packetbeat" "auditbeat" "metricbeat")
            break
        elif [ ${collector_install_list[$select_collector]+exists} ]
        then
            echo "Collector is already added to the list"
        else
            if [ ${supported_collectors[$select_collector]+exists} ]
            then
                echo "Adding collector to the list" 
                collector_install_list[$select_collector]=${supported_collectors[$select_collector]}
                select_collector=""
            else
                echo "You have selected an invalid option"
            fi
        fi
        read -p "Optionally select another collector, otherwise press Enter: " select_collector
        
        if [ -z "$select_collector" ]
        then
            break
        fi
    done

    echo "You have selected: ${collector_install_list[@]}"

    ################### Uninstall Phase ###################

    #Check if $ssl_folder exists
    if [ -d $ssl_folder ]
    then
        read -p "Do you want to remove the certificates from '$ssl_folder'? [Y/n] : " -i "Y" -e remove_certificates
        if [[ $remove_certificates =~ y|Y ]]
        then
            rm -r $ssl_folder
            error_handler "Could not remove folder"
        else
            echo "Did not receive 'yes', keeping certificate directory"
        fi
    fi

    #Uninstall the selected packages    
    for collector in "${collector_install_list[@]}"
    do
        uninstall_package $collector      
    done

    #Ask to clean remaining files
    for collector in "${collector_install_list[@]}"
    do
        if [ -d /etc/$collector ]
        then
            read -p "Some configuration files remained in /etc/$collector. Do you want to remove these? [Y/n] : " -i "Y" -e remove_remainders
            if [[ $remove_remainders =~ y|Y ]]
            then
                rm -r /etc/$collector
                error_handler "Could not remove folder"
            else
                echo "Did not receive 'yes', keeping remainders in /etc/$collector"
            fi
        fi      
    done
    echo "The AntSec Collectors have been successfully uninstalled"
fi