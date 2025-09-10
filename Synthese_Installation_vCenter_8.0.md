# Procédure d'Installation de VMware vCenter Server Appliance (VCSA) 8.0

---

## Prérequis et Environnement

* **Hôte ESXi :**
    * Adresse IP : 10.144.208.32
    * Masque de sous-réseau : 255.255.255.0
    * Passerelle : 10.144.208.1
    * Nom d'utilisateur : root
    * Mot de passe : toto32**
    * Datastore cible : datastore1 (avec suffisamment d'espace disque, minimum 200 Go pour une option "tiny")
* **VCSA :**
    * Adresse IP : 10.144.208.5
    * Masque de sous-réseau (préfixe) : 24
    * Passerelle : 10.144.208.1
    * Nom de la VM : vCenter-8
    * Utilisateur SSO (Single Sign-On) : administrator@vsphere.local
    * Mot de passe OS/SSO : Toto32**
    * Option de déploiement : tiny
* **Routeur/Serveur DNS :** 10.144.208.1 (MikroTik dans notre cas)
* **Outil de déploiement :** vcsa-deploy (situé dans l'ISO de vCenter)

---

## Modifications Apportées à la Configuration Pré-Installation

Pour anticiper ou résoudre certains problèmes, les modifications suivantes ont été apportées aux configurations avant de relancer le déploiement ou pendant le dépannage :

### Fichier de configuration JSON (embedded_vCSA_on_ESXi-8.json)

* **Synchronisation NTP :**
    * Ajout de la clé "ntp_servers" dans la section "network" du fichier JSON pour automatiser la configuration NTP de la VCSA dès le déploiement :
        
        ```json
        "ntp_servers": [
            "0.pool.ntp.org"
        ],
        ```

        (Note : 0.pool.ntp.org ou pool.ntp.org peut être utilisé, et plusieurs serveurs peuvent être spécifiés).
* **Mots de passe :**
    * Vérification et modification des mots de passe définis dans les sections "esxi", "os", et "sso" du fichier JSON (toto32**, Toto32**) pour garantir qu'ils respectent les règles de sécurité strictes de VMware (au moins une majuscule, une minuscule, un chiffre et un caractère spécial).

### Configuration de l'ESXi et du Réseau

* **Masque de sous-réseau de l'ESXi :**
    * Correction manuelle du masque de sous-réseau de l'ESXi de 255.255.0.0 à 255.255.255.0 pour assurer la compatibilité avec le réseau local et la VCSA.
* **Configuration NTP de l'ESXi :**
    * Ajout et activation du serveur NTP (pool.ntp.org) directement sur l'ESXi pour que l'hôte soit synchronisé.

---

## Étapes de l'Installation

L'installation de la VCSA se déroule en deux phases principales. **Dans notre cas, les deux phases ont été entièrement automatisées via un fichier de configuration JSON.**

### Phase 1 & 2 : Déploiement et Configuration de l'Appliance via CLI

1. **Préparation du fichier de configuration :** Créer un fichier JSON (par exemple, vcsa_deploy_config.json) contenant tous les paramètres de déploiement et de configuration de la VCSA. Ce fichier doit inclure les informations pour l'hôte ESXi, les paramètres réseau de la VCSA, les mots de passe du système d'exploitation et du SSO, ainsi que les informations de synchronisation horaire (NTP) et de domaine SSO.
2. **Accéder à l'outil de déploiement :** Naviguer vers le répertoire vcsa-ui-installer\<OS>\vcsa-deploy (par exemple, vcsa-ui-installer\win32) depuis l'ISO de vCenter monté.
3. **Exécuter la commande de déploiement :**
    * Pour le déploiement complet d'une **nouvelle VCSA** (incluant la Phase 1 et la Phase 2 automatisée) :
        
        ```bash
        ./vcsa-deploy.exe install --accept-eula --acknowledge-ceip --no-ssl-certificate-validation --json-args vcsa_deploy_config.json
        ```

        * `--accept-eula` : Accepte le contrat de licence.
        * `--acknowledge-ceip` : Accepte la participation (ou non, selon le JSON) au CEIP.
        * `--no-ssl-certificate-validation` : Ignore la validation des certificats SSL (souvent utile en lab avec des certificats auto-signés).
        * `--json-args vcsa_deploy_config.json` : Indique d'utiliser le fichier JSON spécifié pour les arguments de configuration.
4. **Surveiller le processus :** Le déploiement s'exécutera en mode texte dans la console, affichant la progression des deux phases jusqu'à la finalisation.

---

## Problèmes Rencontrés et Solutions

Plusieurs problèmes ont bloqué l'installation. Leur résolution a été progressive :

### Problème 1 : Blocage à la Phase 2 ("Starting VMware License Service...")

* **Diagnostic correct :**
    * **Absence de synchronisation NTP sur l'ESXi :** Le service NTP de l'ESXi était "Arrêté" et non synchronisé, dû à une incapacité à résoudre les noms d'hôtes et à contacter les serveurs NTP publics.
    * **Échec de résolution DNS (nslookup pool.ntp.org) sur l'ESXi :** L'ESXi ne pouvait pas résoudre les noms de domaine externes, indiquant un problème DNS ou de connectivité.
    * **Absence de connectivité Internet (ping 8.8.8.8) sur l'ESXi :** L'ESXi ne pouvait pas atteindre d'adresses IP publiques, confirmant un problème de routage ou de pare-feu vers Internet.

* **Solution pour le problème de blocage :** La résolution des problèmes de réseau de l'ESXi était la clé.

### Problème 2 : Incohérence du masque de sous-réseau sur l'ESXi

* **Symptômes :** L'ESXi était configuré avec un masque de sous-réseau 255.255.0.0 (préfixe /16), alors que le reste du réseau (et la VCSA) utilisait 255.255.255.0 (préfixe /24). Cette divergence empêchait une communication réseau correcte pour les flux externes et la résolution DNS.
* **Solution :** Correction du masque de sous-réseau de l'ESXi

### Problème 3 : Absence de connectivité Internet et résolution DNS sur l'ESXi

* **Symptômes :** Malgré la correction du masque, l'ESXi n'arrivait toujours pas à ping 8.8.8.8 ni à résoudre les noms (nslookup pool.ntp.org retournait SERVFAIL). Cela indiquait un problème au-delà de l'ESXi lui-même, probablement au niveau du routeur.
* **Diagnostic :** Le routeur 10.144.208.1 ne laissait pas passer le trafic Internet pour l'ESXi et/ou ne forwardait pas les requêtes DNS correctement.
* **Solution :** Accès à l'interface de gestion du routeur MikroTik (http://10.144.208.1) et configuration des points suivants :
    * **DNS :** S'assurer que le routeur utilise des serveurs DNS publics (8.8.8.8 par exemple) pour ses propres requêtes.
    * **Routes :** Vérifier la présence d'une route par défaut vers Internet (0.0.0.0/0).
    * **Vérification sur ESXi après correction routeur :**
        * ping - 8.8.8.8 : **Succès**
        * nslookup pool.ntp.org : **Succès** (retourne des IPs)

---
#  Tuto pour automatiser le déploiement de l'infrastructure 

## Prérequis

Avant de commencer, assurez-vous d’avoir :

- Un **NUC** physique disponible pour héberger la machine virtuelle.
- Une infrastructure compatible **VMware ESXi 8.0 U2** ou version ultérieure.
- Un fichier ISO d’**ESXi** prêt à être importé.

---

##  Création de la machine virtuelle

Créer manuellement une VM avec la configuration suivante :

### Configuration générale

| Paramètre                      | Valeur                                      |
|-------------------------------|---------------------------------------------|
| **Compatibilité**             | ESXi 8.0 U2 et versions ultérieures         |
| **Système d’exploitation**    | Autre                                       |
| **Version de compatibilité**  | VMware ESXi 8.0 ou version ultérieure       |
| **Processeurs (vCPU)**        | 2                                           |
| **Mémoire vive (RAM)**        | 16 Go **(très important)**                  |

> **Important :** Activer l’option **"Exposer l’assistance matérielle à la virtualisation au SE invité"** dans les paramètres CPU.

---

### Configuration des disques virtuels

Créer **4 disques** avec les tailles suivantes :

1. **8 Go** – Pour le système
2. **10 Go** – Pour le cache du vSAN
3. **40 Go** – Pour le vSAN (stockage principal)
4. **4 Go** – Pour le petit `vDataStore`

---

### ISO et options de démarrage

- Importer le fichier **ISO** d'installation de l’ESXi.
- Cocher l’option **"Connecter lors de la mise sous tension"** pour le lecteur ISO.

---

## Étape après installation de l’ESXi

Une fois l’ESXi installé sur la VM :

1. **Éteindre la machine virtuelle manuellement**.
2. **Ne pas la rallumer avant l’export** vers un fichier OVA ou OVF.
   > Sinon, l’OVA générée ne sera pas fonctionnell


---

##  Exportation en OVA/OVF

- Exporter la VM éteinte au format **OVA** ou **OVF** via l'interface de vCenter ou de l'ESXi directement.
- Vérifiez que tous les fichiers nécessaires (.ovf, .vmdk, etc.) sont présents dans le cas d’un export OVF.

---

##  Adapter le fichier de configuration

Après l’export :

- Modifier/adapter le fichier de configuration associé à votre **OVA** selon vos besoins.
- S’assurer que les paramètres (CPU, RAM, disques) sont cohérents avec l’infrastructure cible.


##  Exécution du Script `deploy.ps1`

Une fois la VM créée et ESXi installé, utiliser le script `deploy.ps1` pour déployer les vESXi de manière automatisée.


##  TP1 – Configuration réseau pour activer le DHCP

Pour que le serveur **DHCP fonctionne correctement** et que les **tinyVM** reçoivent une adresse IP, il est indispensable d’ajuster la configuration des **vSwitches** à deux niveaux :

###  1. Sur le vSwitch du **ESXi** (hôte physique)

- Cible : Le groupe de ports connecté à la **ESXi**.

###  2. Sur le vSwitch du **vESXi** (hôte virtualisé)

- Cible : Le groupe de ports connecté aux **VMs finales** (comme `tinyVM`).

###  Procédure de configuration (à faire sur les deux niveaux)

1. Accéder au **vSphere Client**.
2. Aller dans `Configurer` > `Mise en réseau`.
3. Sélectionner le **vSwitch approprié**.
4. Éditer les **paramètres du groupe de ports** concerné.
5. Aller dans l'onglet **Sécurité** et modifier les options suivantes :
   - **Mode Promiscuous** : `Accepter`
   - **Changements d'adresse MAC** : `Accepter`
   - **Transmissions forgées** : `Accepter`

> Cela permet au serveur DHCP de transmettre les adresses IP correctement aux VMs hébergées dans l’environnement virtualisé.



```bash

cd "C:\Users\newuser\Desktop\Stage_IMT\nestedesx-master"

.\delete-infra.ps1

.\deploy.ps1 -nopwd

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

```