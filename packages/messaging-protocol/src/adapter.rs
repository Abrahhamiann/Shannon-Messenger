//! Snapshot adapter. The Android caller must atomically commit returned state
//! with history/outbox; this module never writes files or accesses the network.
use std::collections::BTreeMap;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use vodozemac::{Curve25519PublicKey, olm::{Account, AccountPickle, OlmMessage, Session, SessionConfig, SessionPickle}};

#[derive(Serialize,Deserialize)]
struct Snapshot {
 account: AccountPickle,
 #[serde(default)]
 sessions: BTreeMap<String,SessionPickle>,
}
fn field<'a>(request:&'a Value,key:&str)->Result<&'a str,&'static str>{
 request[key].as_str().filter(|s|s.len()<=100000).ok_or("invalid_request")
}
fn curve(value:&str)->Result<Curve25519PublicKey,&'static str>{
 let bytes=URL_SAFE_NO_PAD.decode(value).map_err(|_|"invalid_key")?;
 let bytes:[u8;32]=bytes.try_into().map_err(|_|"invalid_key")?;
 Ok(Curve25519PublicKey::from_bytes(bytes))
}
fn serialized(account:&Account,sessions:BTreeMap<String,Session>)->Result<Value,&'static str>{
 serde_json::to_value(Snapshot{account:account.pickle(),sessions:sessions.into_iter().map(|(id,s)|(id,s.pickle())).collect()}).map_err(|_|"serialization_failed")
}

pub fn process(request:Value)->Result<Value,&'static str>{
 let op=field(&request,"op")?;
 let (mut account,mut sessions)=if request["state"].is_null(){
  if op!="initialize"{return Err("state_missing")}
  (Account::new(),BTreeMap::new())
 }else{
  let state:Snapshot=serde_json::from_value(request["state"].clone()).map_err(|_|"state_invalid")?;
  if state.sessions.len()>8{return Err("session_limit")}
  (Account::from_pickle(state.account),state.sessions.into_iter().map(|(id,p)|(id,Session::from_pickle(p))).collect::<BTreeMap<String,Session>>())
 };
 let mut output=json!({"curve":URL_SAFE_NO_PAD.encode(account.curve25519_key().as_bytes()),"signing":URL_SAFE_NO_PAD.encode(account.ed25519_key().as_bytes())});
 match op {
  "initialize"=>{},
  "publish"=>{
   let context=field(&request,"context")?;
   if context.len()>256||context.contains('\r'){return Err("invalid_context")}
   let desired=request["needed"].as_u64().unwrap_or(50).min(50) as usize;
   let fresh=desired.saturating_sub(account.one_time_keys().len());
   if account.stored_one_time_key_count()+fresh>5000{return Err("prekey_storage_limit")}
   if fresh>0{account.generate_one_time_keys(fresh);}
   let mut prekeys=Vec::new();
   for key in account.one_time_keys().values(){
    let encoded=URL_SAFE_NO_PAD.encode(key.as_bytes());
    let statement=format!("shannon-messaging-prekey-v1\n{}\n{}\n{}\n{}\n{}",context,output["curve"].as_str().ok_or("invalid_key")?,output["signing"].as_str().ok_or("invalid_key")?,encoded,encoded);
    prekeys.push(json!({"id":encoded,"key":encoded,"signature":URL_SAFE_NO_PAD.encode(account.sign(statement.as_bytes()).to_bytes())}));
   }
   output["prekeys"]=json!(prekeys);
  },
  "mark_published"=>account.mark_keys_as_published(),
  "encrypt"=>{
   let peer=curve(field(&request,"peer_curve")?)?;
   let plaintext=field(&request,"plaintext")?;
   if plaintext.is_empty()||plaintext.len()>16384{return Err("plaintext_size")}
   let selected=request["session"].as_str().map(str::to_owned).or_else(||sessions.keys().next_back().cloned());
   let id=if let Some(id)=selected{
    if !sessions.contains_key(&id){return Err("session_missing")};id
   }else{
    let key=curve(field(&request,"prekey")?)?;
    let session=account.create_outbound_session(SessionConfig::version_1(),peer,key).map_err(|_|"key_agreement_failed")?;
    let id=session.session_id();sessions.insert(id.clone(),session);id
   };
   let packet=sessions.get_mut(&id).ok_or("session_missing")?.encrypt(plaintext).map_err(|_|"encryption_failed")?;
   let (kind,bytes)=packet.to_parts();
   output["session"]=json!(id);output["type"]=json!(kind);output["ciphertext"]=json!(URL_SAFE_NO_PAD.encode(bytes));
  },
  "decrypt"=>{
   let peer=curve(field(&request,"peer_curve")?)?;
   let data=URL_SAFE_NO_PAD.decode(field(&request,"ciphertext")?).map_err(|_|"ciphertext_invalid")?;
   if data.is_empty()||data.len()>65536{return Err("ciphertext_size")}
   let kind=request["type"].as_u64().filter(|n|*n<=1).ok_or("type_invalid")?;
   let packet=OlmMessage::from_parts(kind as usize,&data).map_err(|_|"ciphertext_invalid")?;
   let mut accepted=None;
   for (id,session) in sessions.iter_mut(){
    let mut candidate=Session::from_pickle(session.pickle());
    if let Ok(plaintext)=candidate.decrypt(&packet){*session=candidate;accepted=Some((id.clone(),plaintext));break}
   }
   if accepted.is_none(){
    if let OlmMessage::PreKey(prekey)=&packet{
     if sessions.contains_key(&prekey.session_id()){return Err("decryption_failed")}
     if sessions.len()>=8{return Err("session_limit")}
     let incoming=account.create_inbound_session(SessionConfig::version_1(),peer,prekey).map_err(|_|"decryption_failed")?;
     let id=incoming.session.session_id();sessions.insert(id.clone(),incoming.session);accepted=Some((id,incoming.plaintext));
    }
   }
   let (id,plaintext)=accepted.ok_or("decryption_failed")?;
   if plaintext.len()>16384{return Err("plaintext_size")}
   output["session"]=json!(id);output["plaintext"]=json!(String::from_utf8(plaintext).map_err(|_|"plaintext_invalid")?);
  },
  _=>return Err("operation_unavailable"),
 }
 output["state"]=serialized(&account,sessions)?;
 Ok(output)
}

pub fn invoke(input:&str)->String{
 if input.len()>8*1024*1024{return "{\"error\":\"request_size\"}".into()}
 let result=serde_json::from_str(input).map_err(|_|"invalid_request").and_then(process);
 match result{Ok(value)=>value.to_string(),Err(code)=>json!({"error":code}).to_string()}
}

#[cfg(test)]
mod tests{
 use super::*;
 #[test]
 fn replenishment_keeps_outstanding_private_prekeys_and_stable_identity(){
  let a=process(json!({"op":"initialize"})).expect("sender");
  let b=process(json!({"op":"initialize"})).expect("recipient");
  let published=process(json!({"op":"publish","state":b["state"],"context":"account\ndevice\n1","needed":2})).expect("initial inventory");
  assert_eq!(published["prekeys"].as_array().expect("keys").len(),2);
  // A publication retry must return the same keys rather than rotating them.
  let retry=process(json!({"op":"publish","state":published["state"],"context":"account\ndevice\n1","needed":2})).expect("retry");
  // Public keys are returned from a map; reloading a snapshot need not retain
  // iteration order. Compare every entry/signature without an ordering oracle.
  let mut expected=published["prekeys"].as_array().expect("published keys").clone();
  let mut actual=retry["prekeys"].as_array().expect("retried keys").clone();
  expected.sort_by_key(|entry|entry["id"].as_str().expect("key id").to_owned());
  actual.sort_by_key(|entry|entry["id"].as_str().expect("key id").to_owned());
  assert_eq!(actual,expected);
  let marked=process(json!({"op":"mark_published","state":retry["state"]})).expect("mark");
  let pending=process(json!({"op":"encrypt","state":a["state"],"peer_curve":b["curve"],"prekey":published["prekeys"][0]["key"],"plaintext":"pending during replenishment"})).expect("pending");
  let replenished=process(json!({"op":"publish","state":marked["state"],"context":"account\ndevice\n1","needed":1})).expect("replenish");
  assert_eq!(replenished["curve"],b["curve"]);
  assert_eq!(replenished["signing"],b["signing"]);
  assert_eq!(replenished["prekeys"].as_array().expect("new inventory").len(),1);
  assert_ne!(replenished["prekeys"][0]["key"],published["prekeys"][0]["key"]);
  let received=process(json!({"op":"decrypt","state":replenished["state"],"peer_curve":a["curve"],"type":pending["type"],"ciphertext":pending["ciphertext"]})).expect("old private prekey retained");
  assert_eq!(received["plaintext"],"pending during replenishment");
  let marked=process(json!({"op":"mark_published","state":received["state"]})).expect("mark replacement");
  let full=process(json!({"op":"publish","state":marked["state"],"context":"account\ndevice\n1","needed":0})).expect("inventory full");
  assert!(full["prekeys"].as_array().expect("no surplus").is_empty());
 }
 #[test]
 fn adapter_snapshots_exchange_without_process_memory_state(){
  let a=process(json!({"op":"initialize"})).expect("initialize");
  let b=process(json!({"op":"initialize"})).expect("initialize");
  let b=process(json!({"op":"publish","state":b["state"],"context":"account\ndevice\n1"})).expect("publish");
  let sent=process(json!({"op":"encrypt","state":a["state"],"peer_curve":b["curve"],"prekey":b["prekeys"][0]["key"],"plaintext":"actual library ciphertext"})).expect("encrypt");
  let received=process(json!({"op":"decrypt","state":b["state"],"peer_curve":a["curve"],"type":sent["type"],"ciphertext":sent["ciphertext"]})).expect("decrypt");
  assert_eq!(received["plaintext"],"actual library ciphertext");
  let replay=process(json!({"op":"decrypt","state":received["state"],"peer_curve":a["curve"],"type":sent["type"],"ciphertext":sent["ciphertext"]}));assert!(replay.is_err());
 }
}
