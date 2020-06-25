#!/bin/zsh
## USAGE

### 1. Run the setup with `./instagram-posts-from-instaloader.sh setup`
### 2. Execute the update `./instagram-posts-from-instaloader.sh run-update`

## Config

### Where is your blog located?
blog="/Users/brunoamaral/Labs/Digital-Insanity"
### What is your Instagram Username?
instagramUser="brunoamaral"
### Where are we saving the output from Instaloader? (do not include the username)
directoryWithInstagramPosts="/Users/brunoamaral/Labs/instagram/"

### Where do you want photos saved to? Relative to ./content 
instagramdir="instagram"

# Dependency check

command -v instaloader >/dev/null 2>&1 || { echo >&2 "I require Instaloader but it's not installed. Aborting.";  }
command -v xzcat >/dev/null 2>&1 || { echo >&2 "I require xzcat but it's not installed. Aborting.";  }
command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed. Aborting.";  }
command -v hugo >/dev/null 2>&1 || { echo >&2 "I require hugo but it's not installed. Aborting.";  }

setup() {
  cd /Users/brunoamaral/Labs/instagram; 
  instaloader --fast-update --geotags --login=$instagramUser $instagramUser
}

run-update(){
  find "$directoryWithInstagramPosts/$instagramUser" -maxdepth 1 -name '*.json.xz'  -exec ./instagram-posts-from-instaloader.sh update-post {} \;
}  >&2

update-post() {
  file=$(basename $1)
  dir=$(dirname $1)
  imagefinal=${file//'json.xz'/'jpg'}
  content=`xzcat "$1" | jq '.node.edge_media_to_caption.edges[0].node.text'`

  declare -a tags;
  tags=$(echo $content | grep -o '#[[:alpha:]|[:alnum:]]*')
  jsontags=$(printf '%s' "${tags[@]}" | jq -R . | jq -s .)
  jsontags=${jsontags//[$'\t\r\n'|$' ']}
  jsontags=${jsontags//'#'/}
  date=`cut -d'_' -f 1 <<< "$file"`
  time=`cut -d'_' -f 2 <<< "$file"`

  export post_image=$imagefinal;
  export post_datetime=$(echo $date"T"${time//-/:}"+00:00")
  export post_tags=$jsontags
  if [[ $content = null ]]; then
    export post_slug
    export post_title=$date
    export post_content=" "
  else
    slug=$(echo "$content" |  iconv -c -t ascii//TRANSLIT | sed -E 's/[~\^]+//g' | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+\|-+$//g' | sed -E 's/-$//g' | tr A-Z a-z )
    export post_slug=${slug:0:25}
    title=${content:0:50}
    export post_title=${title//'"'}
    export post_content=$content
  fi

  locationfile=${file//.json.xz/_location.txt}

  grepLocation=$directoryWithInstagramPosts
  grepLocation+="$instagramUser/"$locationfile

  location=$(grep -s 'maps.google.com' $grepLocation)
  if [[ ! -z "$location"  ]]; then
  echo "found $location"
    export google_maps_link=$location 
    locationClean=${location/'&ll'/}
    export latitude=$(cut -d'=' -f 2 <<< "$locationClean" | cut -d'\' -f 1 | cut -d',' -f 1)
    export longitude=$(cut -d'=' -f 2 <<< "$locationClean" | cut -d'\' -f 1 | cut -d',' -f 2)
  fi

  destination="$blog/content/$instagramdir/$date-$time$post_slug/"
  if [[ ! -f "$destination/index.md"  ]]; then
    hugo new $instagramdir/$date-$time$post_slug/index.md
    cp ${1:r:r}(*.jpg|*.mp4) $destination
  else
    echo 'post exists: '$post_title
    # exists=$(ls -alh  content/instagram/$date-$time$post_slug/ &> /dev/null | wc -l | sed -e 's/^[[:space:]]*//')
    # if [[ $exists -gt 0 ]]; then
    #   id=$(($exists + 1))
    #   hugo new instagram/$date-$time$post_slug-$id/index.md
    #   cp ${1:r:r}(*.jpg|*.mp4) content/instagram/$date-$time$post_slug-$id/
    # fi
  fi

}  >&2

if [[ $1 = "setup" ]]; then
  setup
fi

if [[ $1 = "run-update" ]]; then
  run-update
fi

if [[ $1 = "update-post" ]]; then
  update-post $2
fi
