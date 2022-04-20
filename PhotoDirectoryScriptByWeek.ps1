clear-host;
Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
Write-Host "#   Script de Generation de dossier par semaine         #"
Write-Host "#   Cree une arborescence par semaine et mois           #"
Write-Host "#   ~\[Annee]\[Mois]\Semaine du [start] au [end] [Mois] #"
Write-Host "#   Script creer par ROSKOVA                            #"
Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
# Année à générer   
$annee = 2022; 
# Jour du premier dimanche du mois 
$debutSA = (2,6,6,3,1,5,3,7,4,2,6,4); 
# Nombre de dimanche dans le mois
$nbSA=(5,4,4,4,5,4,5,4,4,5,4,4);
# Nombre de jour en février        
$nbFev = 28;
read-host  "Appuyez sur n'importe ENTER pour lancer le script";
$moisA = ("Janvier","Fevrier","Mars","Avril","Mai","Juin","Juillet","Aout","Septembre","Octobre","Novembre","Decembre");$NbJA = (31,$nbFev,31,30,31,30,31,31,30,31,30,31);mkdir "$annee";for ($j = 0; $j -lt 11; $j++) {[int]$nbM = $j; $mois = $moisA[$nbM];$moisS = $moisA[$nbM+1];$nbJ = $NbJA[$nbM];[int]$debutS = $debutSA[$nbM];[int]$finS = $debutS+6; [int]$nbS = $nbSA[$nbM];mkdir "$annee\$mois"; for ($i = $nbS; $i -gt 0; $i--){if($nbM -eq 11){$MoisS = $moisA[0]}if($debutS -gt $finS){mkdir "$annee\$mois\Semaine du $debutS au 0$finS $moisS";}elseif($debutS -lt 10 -and $finS -ge 10){mkdir "$annee\$mois\Semaine du 0$debutS au $finS $mois";}elseif($debutS -lt 10 -and $finS -lt 10){mkdir "$annee\$mois\Semaine du 0$debutS au 0$finS $mois";}elseif($debutS -ge 10 -and $finS -lt 10){mkdir "$annee\$mois\Semaine du $debutS au 0$finS $mois";}else{mkdir "$annee\$mois\Semaine du $debutS au $finS $mois";}if(($finS+7) -gt $nbJ){$finS -=$nbJ;$debutS +=7}else{$debutS += 7;}$finS += 7;}}; read-host "Creation terminer"
