#!/bin/sh
# meo router script
# by zipleen <at> gmail <dot> com
# v. 0.5
# 24/12/2012 - o voip usa a gama a seguir ah que eu tinha definido, apesar da meo so usar essa gama de ips, tive de meter o resto da gama
# 25/12/2010 - rp_filter tem de estar off para multicast funcionar!! tomato fixed!
# 07/11/2010 - wireless ebtables drop multicast
# 06/11/2010 - usar o iface para ficar compativel com ddwrt
# 28/10/2010 - a rede 10.173.0.0 eh melhor em vez da 10.172.192 pois havia hosts 10.173.7.X a quererem enviar streams! added a 10.173.x.x ao forward
# 22/10/2010 - release inicial, ver http://blog.lvengine.com/articles/how-to-make-meo-fiber-iptv-service-work-with-another-router

iface=$interface

deconfig() {
 ifconfig $iface 0.0.0.0
}

bound() {
  #debug das environment variables
  #env > /tmp/env
  
  # definir o ip
  ifconfig $iface $ip netmask $subnet
 	
  # rp_filter tem de estar off na vlan12!!!
  echo 0 > /proc/sys/net/ipv4/conf/$iface/rp_filter
   
  # o route original - a rota seguinte ja trata desta, ptt esta n eh necessaria
  #route add -net 10.194.128.0 netmask $subnet gw $router dev $iface 
  
  # 10.173.192.0 - 10.173.255.254
  ## 10.173.192.0 / 255.255.192.0 / 18
  ## http://www.aboutmyip.com/AboutMyXApp/SubnetCalculator.jsp?ipAddress=10.173.192.0&cidr=18
  #route add -net 10.173.192.0 netmask 255.255.192.0 gw $router dev $iface 
  # parece que ha 10.172.x.x a mandarem streams iptv!
  route add -net 10.173.0.0 netmask 255.255.0.0 gw $router dev $iface
 
  # 194.65.46.0 - 194.65.47.254
  ## 194.65.46.0 / 255.255.254.0 / 23 
  ## http://www.aboutmyip.com/AboutMyXApp/SubnetCalculator.jsp?ipAddress=194.65.46.0&cidr=23 
  route add -net 194.65.46.0 netmask 255.255.254.0 gw $router dev $iface
  
  # 213.13.[16-24]
  ## isto eh estranho, este aqui so da ate 23.254! sera que o anterior era a 46.0 -> 46.254 em vez de 46.0 -> 47.254 ?!
  ## 213.13.16.0 / 255.255.248.0 / 21
  ## http://www.aboutmyip.com/AboutMyXApp/SubnetCalculator.jsp?ipAddress=213.13.16.0&cidr=21
  route add -net 213.13.16.0 netmask 255.255.240.0 gw $router dev $iface 
   
  # FORWARD parece ser preciso para passar os packets daquelas outras redes para a rede local
  # SNAT para a br0 conseguir aceder ah nossa redes privadas iptv
  echo "#!/bin/sh" > /tmp/iptablesiptv.sh 
  echo "if [ \`iptables -L -t nat -n | grep 194.65.46.0/23 | wc -l\` -eq 0 ]; then" >> /tmp/iptablesiptv.sh
  echo "iptables -I INPUT 1 -p igmp -j ACCEPT" >> /tmp/iptablesiptv.sh
  echo "iptables -I INPUT 1 -i $iface -p udp --dst 224.0.0.0/4 --dport 1025: -j ACCEPT" >> /tmp/iptablesiptv.sh
  # pela razao la de cima, vamos adicionar a 10.173.* ao forward
  #echo "iptables -I INPUT 1 -i $iface -s 194.65.46.0/23 -p udp -j ACCEPT" >> /tmp/iptablesiptv.sh
  #echo "iptables -I FORWARD -i $iface -o br0 -s 10.173.192.0/18 -j ACCEPT" >> /tmp/iptablesiptv.sh 
  echo "iptables -I FORWARD -i $iface -o br0 -s 10.173.0.0/16 -j ACCEPT" >> /tmp/iptablesiptv.sh
  echo "iptables -I FORWARD -i $iface -o br0 -s 194.65.46.0/23 -j ACCEPT" >> /tmp/iptablesiptv.sh
  echo "iptables -I FORWARD -i $iface -o br0 -s 213.13.16.0/20 -j ACCEPT" >> /tmp/iptablesiptv.sh
  # o router original parece nao dar acesso ah rede 10.x ...
  #echo "iptables --table nat -I POSTROUTING 1 --out-interface $iface --source 192.168.1.0/24 --destination 10.173.192.0/18 --jump SNAT --to-source $ip" >> /tmp/iptablesiptv.sh
  #echo "iptables --table nat -I POSTROUTING 1 --out-interface $iface --source 192.168.1.0/24 --destination 10.173.0.0/16 --jump SNAT --to-source $ip" >> /tmp/iptablesiptv.sh
  echo "iptables --table nat -I POSTROUTING 1 --out-interface $iface --source 192.168.1.0/24 --destination 194.65.46.0/23 --jump SNAT --to-source $ip" >> /tmp/iptablesiptv.sh
  echo "iptables --table nat -I POSTROUTING 1 --out-interface $iface --source 192.168.1.0/24 --destination 213.13.16.0/20 --jump SNAT --to-source $ip" >> /tmp/iptablesiptv.sh
  
  # ebtables necessita build > 52!
  #echo "ebtables -t nat -F" >> /tmp/iptablesiptv.sh 
  #echo "ebtables -t nat -A OUTPUT -o eth1 -d Multicast -p 0x800 --ip-proto udp --ip-dst 239.255.255.250/32 -j ACCEPT" >> /tmp/iptablesiptv.sh
  #echo "ebtables -t nat -A OUTPUT -o eth1 -d Multicast -j DROP" >> /tmp/iptablesiptv.sh
  
  #echo "iptables --table nat -I POSTROUTING 1 --out-interface $iface --source 192.168.1.0/24 --destination 213.13.18.164/32 --jump SNAT --to-source $ip" >> /tmp/iptablesiptv.sh
  echo "fi" >> /tmp/iptablesiptv.sh
  chmod +x /tmp/iptablesiptv.sh
}

renew() {
  # sou lazy e vou correr apenas os comandos todos outra vez! parece workar :P
  bound
}

case $1 in
        deconfig)
              deconfig
              ;;
        bound)
              bound
              ;;
        renew)
              renew
              ;;
        update)
      	      renew
              ;;
esac
                                                                                                                        
