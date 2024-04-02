          
      $ya_vm_name="node4"
      $ya_vm_image="ubuntu-2204-lts"
      $ya_network_name="default"
      $ya_zone="ru-central1-b"
      $ya_subnet="default-ru-central1-b"
      $ya_account="svc_prod"
      $ya_cloud_id="b1gi91nvj5m7ajci95v9"
      $ya_folder_id="b1g2fitjlfgjp12no5tv"
      $ya_account_key="C:\Users\User\key_prod.json"   
      $ya_HDD_size="20"    
      $ya_memory="8" 
      $ya_cores="2"
      $settings_file="C:\Users\User\prod.txt"   
          
          
      yc config set cloud-id $ya_cloud_id
      yc config set folder-id $ya_folder_id
      yc config set service-account-key $ya_account_key


      yc compute instance create --name $ya_vm_name --zone $ya_zone --network-interface subnet-name=$ya_subnet,nat-ip-version=ipv4 --create-boot-disk type=network-hdd,size=$ya_HDD_size,image-folder-id=standard-images,image-family=$ya_vm_image --ssh-key=$settings_file --memory $ya_memory --cores $ya_cores --core-fraction 20 --platform-id standard-v3 --preemptible 