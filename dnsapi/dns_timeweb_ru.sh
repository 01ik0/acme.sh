#!/usr/bin/env sh

#
#TW_Ru_App_Key="YOUR_APP_KEY"
#TW_Ru_Token="YOUR_API_TOKEN"
#TW_Ru_Login="YOUR_LOGIN"
#

TW_Ru_Api="https://api.timeweb.ru/v1.2"

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_timeweb_ru_add() {
  fulldomain=$1
  txtvalue=$2

  TW_Ru_App_Key="${TW_Ru_App_Key:-$(_readaccountconf_mutable TW_Ru_App_Key)}"
  TW_Ru_Token="${TW_Ru_Token:-$(_readaccountconf_mutable TW_Ru_Token)}"
  TW_Ru_Login="${TW_Ru_Login:-$(_readaccountconf_mutable TW_Ru_Login)}"

  if [ -z "$TW_Ru_App_Key" ]; then
    TW_Ru_App_Key=""
    _err "You don't specify timeweb app key yet."
    _err "Please add your app key and try again."
    return 1
  fi

  if [ -z "$TW_Ru_Token" ]; then
    TW_Ru_Token=""
    _err "You don't specify timeweb api token yet."
    _err "Please add your api token and try again."
    return 1
  fi

  if [ -z "$TW_Ru_Login" ]; then
    TW_Ru_Login=""
    _err "You don't specify timeweb login yet."
    _err "Please create you login and try again."
    return 1
  fi

  #save the credentials  to the account conf file.
  _saveaccountconf_mutable TW_Ru_App_Key "$TW_Ru_App_Key"
  _saveaccountconf_mutable TW_Ru_Token "$TW_Ru_Token"
  _saveaccountconf_mutable TW_Ru_Login "$TW_Ru_Login"

 # _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
 fi
  _debug _sub_domain "$sub_domain"
  _debug _domain "$domain"

  _info "Adding record"
# POST /v1.2/accounts/{login}/domains/{domain}/user-records/
  if _tw_rest POST "accounts/$TW_Ru_Login/domains/$domain/user-records/" "{\"data\": {\"subdomain\": \"$sub_domain\", \"value\": \"$txtvalue\"}, \"type\": \"TXT\"}"; then
    if _contains "$response" "$txtvalue" || _contains "$response" "dns_record_exists"; then
      _info "Added, OK"
      return 0
    fi
  fi
  _err "Add txt record error."
  return 1
}

set -x
#fulldomain txtvalue
dns_timeweb_ru_rm() {
  fulldomain=$1
  txtvalue=$2

  TW_Ru_App_Key="${TW_Ru_App_Key:-$(_readaccountconf_mutable TW_Ru_App_Key)}"
  TW_Ru_Token="${TW_Ru_Token:-$(_readaccountconf_mutable TW_Ru_Token)}"
  TW_Ru_Login="${TW_Ru_Login:-$(_readaccountconf_mutable TW_Ru_Login)}"

  if [ -z "$TW_Ru_App_Key" ]; then
    TW_Ru_App_Key=""
    _err "You don't specify timeweb app key yet."
    _err "Please add your app key and try again."
    return 1
  fi

  if [ -z "$TW_Ru_Token" ]; then
    TW_Ru_Token=""
    _err "You don't specify timeweb api token yet."
    _err "Please add your api token and try again."
    return 1
  fi

  if [ -z "$TW_Ru_Login" ]; then
    TW_Ru_Login=""
    _err "You don't specify timeweb login yet."
    _err "Please add your login and try again."
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
  # GET /v1.2/accounts/{login}/domains/{domain}/user-records
  # default limit: 10 records
  _tw_rest GET "accounts/$TW_Ru_Login/domains/$domain/user-records?limit=100"

  if ! _contains "$response" "$txtvalue"; then
    _err "Txt record not found"
    return 1
  fi

  # example response
  # "[{\"data\":{\"subdomain\":\"_acme-challenge\",\"value\":\"l3ZfDV-fj4YfIbe8EVLU10rSSsPiWyxYvufC-XXXXX\"},\"id\":1234567,\"type\":\"TXT\"}]"
  _record_seg="$(echo "$response" | egrep -o "\"value\":\"$txtvalue\"},\"id\":[0-9]+")"
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

  # DELETE /v1.2/accounts/{login}/domains/$domain/user-records/{idrecords}
  if ! _tw_rest DELETE "accounts/$TW_Ru_Login/domains/$domain/user-records/$_record_id"; then
    _err "Delete record error. echo $fulldomain; echo $_record_id"
    return 1
  fi
  return 0
}
set +x
####################  Private functions below ##################################
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  fulldomain=$1
  domain=$(printf "%s" "$fulldomain" | rev | cut -d . -f1,2 | rev)
  sub_domain=$(printf "%s" "$fulldomain" | rev | cut -d . -f3-100 | rev)

  if ! _tw_rest GET "accounts/$TW_Ru_Login/domains/$domain"; then
    return 1
  fi

}

_tw_rest() {
  m=$1
  ep="$2"
  data="$3"
  _debug "$ep"

  export _H1="accept: */*"
  export _H2="x-app-key: $TW_Ru_App_Key"
  export _H3="Authorization: Bearer $TW_Ru_Token"
  export _H4="Content-Type: application/json"

  if [ "$m" != "GET" ]; then
    _debug data "$data"
     response="$(_post "$data" "$TW_Ru_Api/$ep" "" "$m")"
  else
    response="$(_get "$TW_Ru_Api/$ep")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
