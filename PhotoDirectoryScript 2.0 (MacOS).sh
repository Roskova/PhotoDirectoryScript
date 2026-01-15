#!/usr/local/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#   Auto Sorting script by week and year base on EXIF   #
#   By ROSKOVA        V2.0         Created: 2025-10-18  #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# ============= CONFIGURATION =============
# RECURSIVE: 1 = trier tous les sous-répertoires, 0 = seulement le dossier actuel
RECURSIVE=1

# TRANSFER_MODE: "move" (mv) pour déplacer (par défaut) ou "copy" (cp) pour copier
TRANSFER_MODE="move"

# CLEANUP_EMPTY_FOLDERS: 1 = supprimer les dossiers vides après le tri, 0 = garder les dossiers vides
CLEANUP_EMPTY_FOLDERS=1

# SOURCE_FOLDER_NAME: nom du sous-dossier à trier
# "#" = dossier par défaut ($HOME/Pictures/Automatique_Triage)
# "." = dossier où se trouve le script
# "DCIM" ou autre = sous-dossier du script
SOURCE_FOLDER_NAME="#"

# DESTINATION_NAME: nom du disque de destination
# "#" = défaut (Mon Volume/Photographie)
# "." = créer l'arborescence dans le dossier du script
# "Mon Disque" = utiliser /Volumes/Mon Disque/Photographie
DESTINATION_NAME="#"

# SKIP_DUPLICATE_CHECK: 1 = ignorer la vérification avancée des doublons (shasum, renommage) pour gagner du temps, 0 = garder la logique avancée
SKIP_DUPLICATE_CHECK=0 

# SKIP_PREVIEW: 1 = désactiver la prévisualisation et la boîte de dialogue de confirmation (mode automatique), 0 = prévisualiser et demander confirmation (par défaut)
SKIP_PREVIEW=1
# =========================================

# Déterminer le dossier source
if [ "$SOURCE_FOLDER_NAME" = "#" ]; then
    SOURCE_FOLDER="$HOME/Pictures/Automatique_Triage"
elif [ "$SOURCE_FOLDER_NAME" = "." ]; then
    SOURCE_FOLDER="$(cd "$(dirname "$0")" && pwd)"
else
    SOURCE_FOLDER="$(cd "$(dirname "$0")" && pwd)/$SOURCE_FOLDER_NAME"
fi

# Déterminer la destination
if [ "$DESTINATION_NAME" = "#" ]; then
    DESTINATION_ROOT="/Volumes/Mon Volume/Photographie"
elif [ "$DESTINATION_NAME" = "." ]; then
    # Si destination = ".", trier dans le dossier source lui-même
    DESTINATION_ROOT="$SOURCE_FOLDER"
else
    DESTINATION_ROOT="/Volumes/$DESTINATION_NAME/Photographie"
fi

# Vérifier que le dossier source existe
if [ ! -d "$SOURCE_FOLDER" ]; then
    osascript -e "display dialog \"Le dossier source '$SOURCE_FOLDER' n'existe pas.\" buttons {\"OK\"} with icon stop"
    exit 1
fi

# Vérifie que le disque est monté
if [ ! -d "$DESTINATION_ROOT" ]; then
    osascript -e 'display dialog "Le disque externe nest pas monté ou le chemin /Photographie est introuvable." buttons {"OK"} with icon stop'
    exit 1
fi

# Fonction pour calculer le premier dimanche d'une année à partir d'une année de référence
# Année de référence: 2000, premier dimanche: 2 janvier
get_premier_dimanche() {
    local target_year=$1
    local ref_year=2000
    local ref_first_sunday=2  # 2 janvier 2000
    
    # Si c'est l'année de référence, retourner directement
    if [ $target_year -eq $ref_year ]; then
        echo $ref_first_sunday
        return
    fi
    
    # Calculer la date du 1er janvier de l'année cible
    local jan1_timestamp=$(date -j -f "%Y-%m-%d" "${target_year}-01-01" "+%s" 2>/dev/null)
    
    # Jour de la semaine du 1er janvier (0=dimanche, 1=lundi, ..., 6=samedi)
    local jan1_weekday=$(date -j -r $jan1_timestamp "+%w")
    
    # Calculer le premier dimanche
    # Si le 1er janvier est un dimanche (0), le premier dimanche est le 1er
    if [ $jan1_weekday -eq 0 ]; then
        echo 1
    else
        echo $((8 - jan1_weekday))
    fi
}

# Fonction pour calculer les paramètres d'une année
calculate_year_params() {
    local year=$1
    
    # Obtenir le premier dimanche
    local premier_dimanche=$(get_premier_dimanche "$year")
    
    if [ -z "$premier_dimanche" ]; then
        echo ""
        return 1
    fi
    
    # Calculer le nombre de jours en février
    if [ $((year % 4)) -eq 0 ] && { [ $((year % 100)) -ne 0 ] || [ $((year % 400)) -eq 0 ]; }; then
        local nb_fev=29
    else
        local nb_fev=28
    fi
    
    # Nombre de jours par mois
    local nb_jours=(31 $nb_fev 31 30 31 30 31 31 30 31 30 31)
    
    # Calculer le nombre de semaines par mois et le début de chaque semaine
    local -a debut_semaine
    local -a nb_semaines
    
    debut_semaine[0]=$premier_dimanche
    
    for ((i=0; i<12; i++)); do
        if [ $i -eq 0 ]; then
            if [ $((nb_jours[0] - 28 - premier_dimanche)) -ge 0 ]; then
                nb_semaines[0]=5
            else
                nb_semaines[0]=4
            fi
            x=$premier_dimanche
        else
            x=$((x + nb_semaines[i-1] * 7 - nb_jours[i-1]))
            if [ $((nb_jours[i] - 28 - x)) -ge 0 ]; then
                nb_semaines[i]=5
            else
                nb_semaines[i]=4
            fi
        fi
    done
    
    # Recalculer debut_semaine pour chaque mois
    debut_semaine[0]=$premier_dimanche
    for ((i=1; i<12; i++)); do
        debut_semaine[i]=$((debut_semaine[i-1] + nb_semaines[i-1] * 7 - nb_jours[i-1]))
    done
    
    # Retourner les valeurs via des variables globales
    eval "year_${year}_nb_jours=(${nb_jours[@]})"
    eval "year_${year}_debut_semaine=(${debut_semaine[@]})"
    eval "year_${year}_nb_semaines=(${nb_semaines[@]})"
}

# Fonction pour trouver le dossier de semaine pour une date donnée
find_week_folder() {
    local file_date=$1
    local file_year=$(date -j -f "%Y-%m-%d" "$file_date" "+%Y" 2>/dev/null)
    local file_month=$(date -j -f "%Y-%m-%d" "$file_date" "+%-m" 2>/dev/null)
    local file_day=$(date -j -f "%Y-%m-%d" "$file_date" "+%-d" 2>/dev/null)
    
    if [ -z "$file_year" ] || [ -z "$file_month" ] || [ -z "$file_day" ]; then
        echo ""
        return
    fi
    
    # Calculer les paramètres de l'année si pas déjà fait
    if ! declare -p "year_${file_year}_nb_jours" &>/dev/null; then
        calculate_year_params "$file_year" || return
    fi
    
    # Récupérer les valeurs pour cette année
    eval "local nb_jours=(\${year_${file_year}_nb_jours[@]})"
    eval "local debut_semaine=(\${year_${file_year}_debut_semaine[@]})"
    eval "local nb_semaines=(\${year_${file_year}_nb_semaines[@]})"
    
    local month_index=$((file_month - 1))
    
    # Noms des mois
    local mois_noms=("Janvier" "Fevrier" "Mars" "Avril" "Mai" "Juin" "Juillet" "Aout" "Septembre" "Octobre" "Novembre" "Decembre")
    
    # Vérifier dans le mois de la photo
    local month_name="${mois_noms[$month_index]}"
    local debut_s=${debut_semaine[$month_index]}
    local fin_s=$((debut_s + 6))
    local nb_s=${nb_semaines[$month_index]}
    local nb_j=${nb_jours[$month_index]}
    
    # Trouver dans quelle semaine se trouve le jour
    for ((s=0; s<nb_s; s++)); do
        # Cas 1: la semaine ne déborde pas sur le mois suivant
        if [ $fin_s -le $nb_j ]; then
            if [ $file_day -ge $debut_s ] && [ $file_day -le $fin_s ]; then
                format_week_folder "$debut_s" "$fin_s" "$month_name" "$month_name" "$file_year"
                return
            fi
        else
            # Cas 2: la semaine déborde sur le mois suivant
            if [ $file_day -ge $debut_s ] && [ $file_day -le $nb_j ]; then
                local next_month_index=$(( (month_index + 1) % 12 ))
                local next_month_name="${mois_noms[$next_month_index]}"
                local actual_fin=$((fin_s - nb_j))
                echo "$file_year/$month_name/Semaine du $(printf "%02d" $debut_s) au $(printf "%02d" $actual_fin) $next_month_name"
                return
            fi
        fi
        
        debut_s=$((debut_s + 7))
        if [ $debut_s -gt $nb_j ]; then
            debut_s=$((debut_s - nb_j))
        fi
        fin_s=$((debut_s + 6))
    done
    
    # Si pas trouvé, vérifier si c'est dans une semaine qui déborde du mois précédent
    if [ $month_index -gt 0 ]; then
        local prev_month_index=$((month_index - 1))
        local prev_month_name="${mois_noms[$prev_month_index]}"
        local prev_nb_j=${nb_jours[$prev_month_index]}
        local prev_debut_s=${debut_semaine[$prev_month_index]}
        local prev_nb_s=${nb_semaines[$prev_month_index]}
        
        # Parcourir les semaines du mois précédent
        for ((s=0; s<prev_nb_s; s++)); do
            local prev_fin_s=$((prev_debut_s + 6))
            
            # Cette semaine déborde-t-elle sur le mois actuel?
            if [ $prev_fin_s -gt $prev_nb_j ]; then
                local overflow_start=1
                local overflow_end=$((prev_fin_s - prev_nb_j))
                
                # Le fichier est dans la partie débordante?
                if [ $file_day -ge $overflow_start ] && [ $file_day -le $overflow_end ]; then
                    # Le fichier va dans le mois PRÉCÉDENT (où commence la semaine)
                    echo "$file_year/$prev_month_name/Semaine du $(printf "%02d" $prev_debut_s) au $(printf "%02d" $overflow_end) $month_name"
                    return
                fi
            fi
            
            prev_debut_s=$((prev_debut_s + 7))
            if [ $prev_debut_s -gt $prev_nb_j ]; then
                prev_debut_s=$((prev_debut_s - prev_nb_j))
            fi
        done
    fi
    
    echo ""
}

# Fonction helper pour formatter le dossier de semaine
format_week_folder() {
    local debut=$1
    local fin=$2
    local month=$3
    local end_month=$4
    local year=$5
    
    local debut_str=$(printf "%02d" $debut)
    local fin_str=$(printf "%02d" $fin)
    
    echo "$year/$month/Semaine du $debut_str au $fin_str $end_month"
}

# Déterminer les options de find selon RECURSIVE
if [ "$RECURSIVE" -eq 1 ]; then
    find_depth=""
else
    find_depth="-maxdepth 1"
fi

# Préparer le fichier de prévisualisation SEULEMENT si nous ne sautons pas l'étape
if [ "$SKIP_PREVIEW" -eq 0 ]; then
    preview_file=$(mktemp)
    echo "Voici les fichiers qui seront déplacés :" > "$preview_file"
    echo "" >> "$preview_file"
fi

# Construction de la liste de tri (prévisualisation)
while IFS= read -r file; do
    
    filename=$(basename "$file")
    
    # Vérifier si c'est un fichier VIDÉO de drone (commence par DJI et extension vidéo)
    if [[ "$filename" =~ ^DJI ]] && [[ "$filename" =~ \.(mp4|MP4|mov|MOV)$ ]]; then
        destination_base="$DESTINATION_ROOT/Drone"
    else
        destination_base="$DESTINATION_ROOT"
    fi
    
    # Essayer d'obtenir la date via exiftool d'abord
    file_date=""
    if command -v exiftool &> /dev/null; then
        file_date=$(exiftool -d "%Y-%m-%d" -DateTimeOriginal -s -s -s "$file" 2>/dev/null)
        
        # Pour les vidéos, essayer CreateDate si DateTimeOriginal n'existe pas
        if [ -z "$file_date" ]; then
            file_date=$(exiftool -d "%Y-%m-%d" -CreateDate -s -s -s "$file" 2>/dev/null)
        fi
    fi
    
    # Si exiftool ne fonctionne pas, utiliser stat
    if [ -z "$file_date" ]; then
        file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null)
    fi
    
    # Validation finale
    if [ -z "$file_date" ] || [[ ! "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "❌ Date invalide ou vide pour $(basename "$file"): '$file_date'" >&2
        continue
    fi
    
    week_path=$(find_week_folder "$file_date")
    
    if [ -z "$week_path" ]; then
        echo "❌ Impossible de trouver le dossier pour $(basename "$file") (date: $file_date)" >&2
        continue
    fi
    
    target_folder="$destination_base/$week_path"

    # LIGNE DE SUIVI UNIQUE (vers stderr pour affichage immédiat en console)
    echo -e "🔎 Prévisualisation : $(basename "$file")\t| Date : $file_date\t| Cible : $([ "$destination_base" == "$DESTINATION_ROOT/Drone" ] && echo "Drone/" || echo "")$week_path" >&2
    
    # Créer le dossier de destination
    mkdir -p "$target_folder"
    
    # Écrit dans le fichier de prévisualisation SEULEMENT si SKIP_PREVIEW est désactivé
    if [ "$SKIP_PREVIEW" -eq 0 ]; then
        echo "📦 $(basename "$file") → $([ "$destination_base" == "$DESTINATION_ROOT/Drone" ] && echo "Drone/" || echo "")$week_path" >> "$preview_file"
    fi
    
done < <(find "$SOURCE_FOLDER" $find_depth -type f \( -iname "*.jpg" -o -iname "*.cr3" -o -iname "*.dng" -o -iname "*.mp4" -o -iname "*.mov" \))

# --- DÉCISION DE CONFIRMATION ---

if [ "$SKIP_PREVIEW" -eq 0 ]; then
    # Mode interactif : Afficher le dialogue et attendre la confirmation
    preview_text=$(cat "$preview_file")
    rm "$preview_file"

    confirmed=$(osascript <<EOF
display dialog "$preview_text" buttons {"Annuler", "Confirmer"} default button "Confirmer" with title "Prévisualisation des transferts" with icon note giving up after 120
return button returned of the result
EOF
    )
    
else
    # Mode automatique : Forcer la confirmation
    confirmed="Confirmer"
    echo "Mode automatique activé (SKIP_PREVIEW=1). Début du transfert..."
fi

# Traitement réel
if [[ "$confirmed" == "Confirmer" ]]; then
    
    TRANSFER_COMMAND="mv"
    if [ "$TRANSFER_MODE" == "copy" ]; then
        TRANSFER_COMMAND="cp"
        echo "ATTENTION: Le script est en mode COPIE. Les fichiers source ne seront PAS supprimés."
    fi
    
    while IFS= read -r file; do
        filename=$(basename "$file")
        
        # Détermination de la base de destination (Drone ou Root)
        if [[ "$filename" =~ ^DJI ]] && [[ "$filename" =~ \.(mp4|MP4|mov|MOV)$ ]]; then
            destination_base="$DESTINATION_ROOT/Drone"
        else
            destination_base="$DESTINATION_ROOT"
        fi
        
        # Re-extraction de la date (identique à la prévisualisation)
        file_date=""
        if command -v exiftool &> /dev/null; then
            file_date=$(exiftool -d "%Y-%m-%d" -DateTimeOriginal -s -s -s "$file" 2>/dev/null)
            if [ -z "$file_date" ]; then
                file_date=$(exiftool -d "%Y-%m-%d" -CreateDate -s -s -s "$file" 2>/dev/null)
            fi
        fi
        if [ -z "$file_date" ]; then
            file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null)
        fi
        
        if [ -z "$file_date" ] || [[ ! "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "❌ Impossible de lire la date pour $(basename "$file") — ignoré."
            continue
        fi
        
        week_path=$(find_week_folder "$file_date")
        
        if [ -z "$week_path" ]; then
            echo "❌ Impossible de trouver le dossier pour $(basename "$file") (date: $file_date)"
            continue
        fi
        
        target_folder="$destination_base/$week_path"
        
        mkdir -p "$target_folder"
        
        # === DÉBUT DE LA LOGIQUE DE GESTION DES CONFLITS ===
        if [ -e "$target_folder/$filename" ]; then
            
            if [ "$SKIP_DUPLICATE_CHECK" -eq 0 ]; then
                # --- LOGIQUE AVANCÉE (lent mais précis) ---
                existing_file="$target_folder/$filename"
                source_hash=$(shasum -a 256 "$file" 2>/dev/null | awk '{print $1}')
                target_hash=$(shasum -a 256 "$existing_file" 2>/dev/null | awk '{print $1}')

                if [ "$source_hash" = "$target_hash" ]; then
                    if [ "$TRANSFER_MODE" == "move" ]; then
                        rm "$file"
                        echo "✅ Doublon parfait trouvé et supprimé (Mode move) : $(basename "$file")"
                    else
                        echo "⚠️ Doublon parfait trouvé. Source conservée (Mode copy) : $(basename "$file")"
                    fi
                else
                    # Logique de renommage en cas de CONFLIT (fichiers différents)
                    base_name="${filename%.*}"
                    extension="${filename##*.}"
                    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
                    DATETIME_FORMAT="%Y-%m-%d-%H%M"
                    
                    if [[ "$extension_lower" =~ ^(cr3|cr2|dng)$ ]]; then
                        new_timestamp=$(stat -f "%Sm" -t "$DATETIME_FORMAT" "$file" 2>/dev/null)
                        new_new_name="${base_name}_EXPORT-${new_timestamp}.${extension}"
                        $TRANSFER_COMMAND "$file" "$target_folder/$new_new_name"
                        echo "💡 $filename ${TRANSFER_COMMAND} vers $new_new_name (RAW existant protégé)"
                    else
                        old_timestamp=$(stat -f "%Sm" -t "$DATETIME_FORMAT" "$existing_file" 2>/dev/null)
                        new_old_name="${base_name}-${old_timestamp}.${extension}"
                        mv "$existing_file" "$target_folder/$new_old_name"
                        echo "♻️ Conflit: L'ancien fichier (non-RAW) est renommé en $new_old_name"
                        
                        new_timestamp=$(stat -f "%Sm" -t "$DATETIME_FORMAT" "$file" 2>/dev/null)
                        new_new_name="${base_name}-${new_timestamp}.${extension}"
                        $TRANSFER_COMMAND "$file" "$target_folder/$new_new_name"
                        echo "💡 $filename ${TRANSFER_COMMAND} vers $new_new_name (nouvel export)"
                    fi
                fi
            else
                # --- LOGIQUE RAPIDE (si SKIP_DUPLICATE_CHECK=1) ---
                # Si le fichier existe et qu'on saute la vérif. shasum, on l'ignore.
                echo "⚠️ $filename existe déjà dans $target_folder. Ignoré (Vérification avancée désactivée)."
                continue
            fi
        
        else
            # Le fichier n'existe pas, on le transfère simplement
            $TRANSFER_COMMAND "$file" "$target_folder"
            echo "✅ $filename ${TRANSFER_COMMAND} vers $target_folder"
        fi
        # === FIN DE LA LOGIQUE DE GESTION DES CONFLITS ===
        
    done < <(find "$SOURCE_FOLDER" $find_depth -type f \( -iname "*.jpg" -o -iname "*.cr3" -o -iname "*.dng" -o -iname "*.mp4" -o -iname "*.mov" \))

    # Nettoyage des dossiers vides
    if [ "$CLEANUP_EMPTY_FOLDERS" -eq 1 ]; then
        echo "Nettoyage des dossiers vides dans $SOURCE_FOLDER..."
        find "$SOURCE_FOLDER" $find_depth -type d -empty -delete
    fi
    
    osascript -e 'display dialog "Tous les fichiers ont été déplacés avec succès !" buttons {"OK"} default button "OK"'
else
    echo "❌ Transfert annulé."
fi
