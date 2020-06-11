#!/bin/bash

declare -ia palya    # tomb ami tarolja a jatek menetet
declare -i pontszam=0   # pont valtozo, amennyi cellat sikerult egymasba huzni
declare -i kihagyas_jelzes #mindig csak egy muvelet hajtodjon vegre egyetlen mezoben egy lepeskor
declare -i mozgasok     # tarolja a lehetseges lepesek szamat annak eldontesere hogy a jatekos elvesztette e a jatekot 
declare -i darabok    # kepernyon levo darabszam
declare -i celpontszam=1024 #ha ezt az erteket eleri a jatekos,nyer

#kulonbozo szamokhoz szin hozzarendelese
declare -a szin #szin tomb deklaralas
szin[2]=35        # lila betuszin (2-es ertekhez 35os,azaz a lila szin kodjanak hozzarendelese)
szin[4]=36        # cian betuszin
szin[8]=34         # kek betuszin
szin[16]=32         # zold betuszin
szin[32]=33         # sarga betuszin 
szin[64]="31m\033[7"      # piros hatterszin
szin[128]="36m\033[7"       # cian hatterszin
szin[256]="34m\033[7"       # kek hatterszin
szin[512]="32m\033[7"       # zold hatterszin
szin[1024]="33m\033[7"        # sarga hatterszin

trap "jatek_vege 0 1" INT #kilepes kezelese jatek vegeteresevel-automatikus vesztes
#jelenlegi jatekallas kiirasa- az utoljara hozzaadott darabok szine piros
function palya_rajzolasa {
  clear #torli az elozo palyat es igy mindig csak az aktualis latszik
  printf "(Mozgatas: W,A,S,D) (Kilepes:CTRL+C) \n"
  printf "Darabok=$darabok Elerendo=$celpontszam Pontszam=$pontszam\n"
  printf "\n"
  printf 'O------¤------¤------¤------O\n' #elso sor rajzolasa
  
  for l in {0..3}; do #sorok szama 0-3 ig az 4db
    printf '|'
    for m in {0..3}; do #oszlopok szama 0-3 ig az 4db
      if let ${palya[l*4+m]}; then
        if let '(legutobb_hozzaadott==(l*4+m))|(elso_kor==(l*4+m))'; then
          printf '\033[1m\033[31m %4d \033[0m|' ${palya[l*4+m]} #legujabban hozzaadott erteku cella beillesztese (PIROS SZIN)
        else
          printf "\033[1m\033[${szin[${palya[l*4+m]}]}m %4d\033[0m |" ${palya[l*4+m]} #korabban hozzaadott erteku cella, szin tomb hozzarendelt szin szerint
        fi
      else
        printf '      |' #amikor ures cella van
      fi
    done
    let l==3 || {
      printf '\n|------' #eleje
      for l in {seq 1 3}; do #seq operator hasznalata l==3 tol 3ig,igy 1 el novel
        printf '¤------' 
      done
      printf '|\n'
    }
  done
  printf '\nO------¤------¤------¤------O\n' #utolso sor rajzolasa
}

# Uj darab generalasa a palyan
# bemenet:
#         $palya  - palya eredeti allapota
#         $darabok - darabok eredeti szama
# kimenet:
#         $palya  - palya uj allapota
#         $darabok - darabok uj szama
function darabok_generalasa { #egy cellaba uj 2es ertek generalasa, random cella.
  while true; do
    let poz=RANDOM%osszes_mezo #random cella pozicio az uj erteknek
    let palya[$poz] || {
      let ertek=RANDOM%10?2:4 #2 vagy 4 lehet az uj ertek
      palya[$poz]=$ertek
      legutobb_hozzaadott=$poz 
      break;
    }
  done
  let darabok++ #darabok szamanak novelese 1-el
}

# ket darab egymasba/ossze csusztatasa
# bemenetek:
#         $1 - pozicioban egyesit, az adott sorra horizontalisan, az oszlopra vertikalisan
#         $2 - amelyik darabba egyesulni fog, ez megtartja az eredmenyt ha mozgatva lesz vagy egyesul
#         $3 - eredeti darab, mozgatas vagy egyesules utan ez uresen marad
#         $4 - egyesites iranya, lehet "fel", "le", "balra" vagy "jobbra"
#         $5 - csak az ervenyes mozgatasok szamanak frissitese,ha valami atkerult-ne egyesitse a cellakat
#         $palya - jatek palyajanak eredeti allapota
# kimenetek:
#         $modosit    - ha a palya modosult az adott korben akkor ezt jelzi
#         $kihagyas_jelzes - ha a darab amibe csusztatnank nem modosithato tovabb akkor ezt jelzi - ezt ki kell hagyni
#         $palya     - jatek palyajanak uj allapota
function darabok_ossze {
  case $4 in
    "fel")
      let "elso=$2*4+$1"
      let "masodik=($2+$3)*4+$1"
      ;;
    "le")
      let "elso=(index_max-$2)*4+$1"
      let "masodik=(index_max-$2-$3)*4+$1"
      ;;
    "balra")
      let "elso=$1*4+$2"
      let "masodik=$1*4+($2+$3)"
      ;;
    "jobbra")
      let "elso=$1*4+(index_max-$2)"
      let "masodik=$1*4+(index_max-$2-$3)"
      ;;
  esac
  let ${palya[$elso]} || { #elso palya, nem a masodik
    let ${palya[$masodik]} && {
      if test -z $5; then
        palya[$elso]=${palya[$masodik]}
        let palya[$masodik]=0
        let modosit=1
        #printf "cella ertek mozgatas ${palya[$elso]} ertekkel a [$masodik] cellabol a [$elso]-be\n"
      else
        let mozgasok++
      fi
      return
    }
    return
  }
  let ${palya[$masodik]} && let kihagyas_jelzes=1 # masodik palya, tehat nem az elso.
  let "${palya[$elso]}==${palya[masodik]}" && { 
    if test -z $5; then
      let palya[$elso]*=2
      let "palya[$elso]==$celpontszam" && jatek_vege 1
      let palya[$masodik]=0
      let darabok-=1
      let modosit=1
      let pontszam+=${palya[$elso]}
      #printf "a cella [$masodik] es cella [$elso] egyesitese, uj ertek=${palya[$elso]}\n"
    else
      let mozgasok++
    fi
  }
}
# az elso es a masodik palya egybeolvasztasa
function mozgatas_vegrehajt {
  for i in $(seq 0 $index_max); do
    for j in $(seq 0 $index_max); do
      kihagyas_jelzes=0
      let max_noveles=index_max-j
      for k in $(seq 1 $max_noveles); do
        let kihagyas_jelzes && break
        darabok_ossze $i $j $k $1 $2
      done 
    done
  done
}

function mozgas_ellenorzes {
  let mozgasok=0
}

function felhasznalo_input { #bekerunk a felhasznalotol egy ervenyes iranyt
  let modosit=0
  read -d '' -sn 1
  test "$REPLY" = "$'\e'" && {
    read -d '' -sn 1 -t1
    test "$REPLY" = "[" && {
      read -d '' -sn 1 -t1
      case $REPLY in
        fel) mozgatas_vegrehajt fel;;
        le) mozgatas_vegrehajt le;;
        jobbra) mozgatas_vegrehajt jobbra;;
        balra) mozgatas_vegrehajt balra;;
      esac
    }
  } || {
    case $REPLY in #mozgatas w,s,d,a gombok valamelyikevel
      w) mozgatas_vegrehajt fel;;
      s) mozgatas_vegrehajt le;;
      d) mozgatas_vegrehajt jobbra;;
      a) mozgatas_vegrehajt balra;;
    esac
  }
}

function jatek_vege {
  palya_rajzolasa
  printf "Elert pontszam: $pontszam\n"

  let $1 && {
    printf "Gratulalok, teljesitett pont: $celpontszam\n"
    exit 0
  }
  printf "\nVeszitettel, mert betelt minden hely es nem erted el az $celpontszam -et.\n"
  exit 0
}

#kezdetleges palya
let osszes_mezo=16
let index_max=3
for i in $(seq 0 $osszes_mezo); do palya[$i]="0"; done #kezdetleges palya feltoltese
let darabok=0
darabok_generalasa
elso_kor=$legutobb_hozzaadott
darabok_generalasa

while true; do #addig,amig igazak a feltetelek es nem vesztette el a jatekot
  palya_rajzolasa
  felhasznalo_input
  let modosit && darabok_generalasa
  elso_kor=-1
  let darabok==osszes_mezo && {
   mozgas_ellenorzes
   let mozgasok==0 && jatek_vege 0 #jatekot elvesztette
  }
done