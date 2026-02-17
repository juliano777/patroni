#!/bin/bash

echo 'Choose an option:'
select OPT in dcs-00 dcs-01 dcs-02; do
  case "${OPT}" in
    dcs-00)
        IP='10'
        break
    ;;

    dcs-01)
        IP='11'
        break
    ;;

    dcs-02)
        IP='12'
        break
    ;;        

    *)
      echo 'Error: Invalid option, try again.'
      ;;
  esac
done

sudo host-ip ${OPT}.patroni.mydomain 192.168.56.${IP} enp0s8

sudo init 0
