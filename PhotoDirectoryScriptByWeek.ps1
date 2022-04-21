clear-host;
Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
Write-Host "#   Script de Generation de dossier par semaine         #"
Write-Host "#   Cree une arborescence par semaine et mois           #"
Write-Host "#   ~\[Annee]\[Mois]\Semaine du [start] au [end] [Mois] #"
Write-Host "#                                                       #"
Write-Host "#   Script creer par ROSKOVA    20-04-2022              #"
Write-Host "# # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
$anneeA = read-host "Annee"
$premierDimancheA = read-host "Date du premier dimanche"
#  Section librairie NE PAS ÉDITER
#  Contient toute les fonctions et variable permettant le calcul du calendrier
[int]$premierDimanche=$premierDimancheA;if($annee%4 -eq 0 -and ($annee % 100 -ne 0 -and $annee % 400 -ne 0)){$nbFev=29;}else{$nbFev=28;}$NbJA=(31,$nbFev,31,30,31,30,31,31,30,31,30,31);
$debutSA=($premierDimanche,0,0,0,0,0,0,0,0,0,0,0);$moisA=("Janvier","Fevrier","Mars","Avril","Mai","Juin","Juillet","Aout","Septembre","Octobre","Novembre","Decembre");[int]$annee=$anneeA;$nbSA=(0,0,0,0,0,0,0,0,0,0,0,0);
for($t=0; $t -lt 12; $t++){if($t -eq 0){if($NbJA[$t]-28-($premierDimanche) -ge 0){$nbSA[$t]=5}else{$nbSA[$t]=4}$x=$premierDimanche}else{$x=$x+($nbSA[$t-1]*7)-$NbJA[$t-1];if($NbJA[$t]-28-($x) -ge 0){$nbSA[$t]=5}else{$nbSA[$t]=4}}}
for($f=1; $f -lt $debutSA.Count;$f++){$debutSA[$f]=$debutSA[$f-1]+($nbSA[$f-1]*7)-$NbJA[$f-1];}
#Section du script de génération
mkdir "$annee";
for ($j = 0; $j -le 11; $j++) {
    #Variable
    [int]$nbM=$j;$mois=$moisA[$nbM];$moisS=$moisA[$nbM+1];$nbJ=$NbJA[$nbM];
    [int]$debutS=$debutSA[$nbM];[int]$finS=$debutS+6;[int]$nbS=$nbSA[$nbM];
    #Création de l'arborescence
    mkdir "$annee\$mois";
    for ($i = $nbS; $i -gt 0; $i--){
        if($debutS -le $nbJ){if($nbM -eq 11){$MoisS = $moisA[0]}
        if($debutS -gt $finS){mkdir "$annee\$mois\Semaine du $debutS au 0$finS $moisS";}
        elseif($debutS -lt 10 -and $finS -ge 10){mkdir "$annee\$mois\Semaine du 0$debutS au $finS $mois";}
        elseif($debutS -lt 10 -and $finS -lt 10){mkdir "$annee\$mois\Semaine du 0$debutS au 0$finS $mois";}
        elseif($debutS -ge 10 -and $finS -lt 10){mkdir "$annee\$mois\Semaine du $debutS au 0$finS $mois";}
        else{mkdir "$annee\$mois\Semaine du $debutS au $finS $mois";}
        if(($finS+7) -gt $nbJ){$finS -=$nbJ;} $finS += 7;$debutS +=7;}
    }
}
read-host "Creation terminer";
