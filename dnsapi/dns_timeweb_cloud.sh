#!/usr/bin/env sh

#
#TW_Cloud_Token="YOUR_API_TOKEN"
#

TW_Cloud_Api="https://api.timeweb.cloud/api/v1"

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_timeweb_cloud_add() {
  fulldomain=$1
  txtvalue=$2

  TW_Cloud_Token="${TW_Cloud_Token:-$(_readaccountconf_mutable TW_Cloud_Token)}"

  if [ -z "$TW_Cloud_Token" ]; then
    TW_Cloud_Token=""
    _err "You don't specify timeweb api token yet."
    _err "Please create you key and try again."
    return 1
  fi

  #save the api key to the account conf file.
  _saveaccountconf_mutable TW_Cloud_Token "$TW_Cloud_Token"

 # _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
 fi
  _debug _sub_domain "$sub_domain"
  _debug _domain "$domain"

  _info "Adding record"
  if _tw_rest POST "domains/$domain/dns-records" "{\"subdomain\": \"$sub_domain\", \"type\": \"TXT\", \"value\": \"$txtvalue\"}"; then
    if _contains "$response" "$txtvalue" || _contains "$response" "record_already_exists"; then
      _info "Added, OK"
      return 0
    fi
  fi
  _err "Add txt record error."
  return 1
}

#fulldomain txtvalue
dns_timeweb_cloud_rm() {
  fulldomain=$1
  txtvalue=$2

  TW_Cloud_Token="${TW_Cloud_Token:-$(_readaccountconf_mutable TW_Cloud_Token)}"

  if [ -z "$TW_Cloud_Token" ]; then
    TW_Cloud_Token=""
    _err "You don't specify timeweb api token yet."
    _err "Please create you key and try again."
    return 1
  fi

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$sub_domain"
  _debug _domain "$domain"

  _debug "Getting txt records"
  # GET /api/v1/domains/{fqdn}/dns-records
  _tw_rest GET "domains/$domain/dns-records"

  if ! _contains "$response" "$txtvalue"; then
    _err "Txt record not found"
    return 1
  fi

  _record_seg="$(echo "$response" | egrep -o "\"value"\":\"$txtvalue\"},\"id\":[0-9]+ )"
  _debug2 "_record_seg" "$_record_seg"
  if [ -z "$_record_seg" ]; then
    _err "can not find _record_seg | RECORD_SEG: $_record_seg | RESP: $response VALUE: $txtvalue"
    return 1
  fi

  _record_id="$(echo "$_record_seg" | tr "," "\n" | sed 's/}//g'| sed '/^$/d'| grep \"id\" | tr -d '"'| cut -d : -f 2)"
  _debug2 "_record_id" "$_record_id"
  if [ -z "$_record_id" ]; then
    _err "can not find _record_id"
    return 1
  fi

  # DELETE /api/v1/domains/$domain/dns-records/{record_id}
  if ! _tw_rest DELETE "domains/$domain/dns-records/$_record_id"; then
    _err "Delete record error. echo $fulldomain; echo $_record_id"
    return 1
  fi
  return 0
}

####################  Private functions below ##################################
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  fulldomain=$1
  domain=$(printf "%s" "$fulldomain" | rev | cut -d . -f1,2 | rev)
  sub_domain=$(printf "%s" "$fulldomain" | rev | cut -d . -f3-100 | rev)

  if ! _tw_rest GET "domains/$domain"; then
    return 1
  fi

}

_tw_rest() {
  m=$1
  ep="$2"
  data="$3"
  _debug "$ep"

  export _H1="Authorization: Bearer $TW_Cloud_Token"
  export _H2="Content-Type: application/json"

  if [ "$m" != "GET" ]; then
    _debug data "$data"
     response="$(_post "$data" "$TW_Cloud_Api/$ep" "" "$m")"
  else
    response="$(_get "$TW_Cloud_Api/$ep")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
