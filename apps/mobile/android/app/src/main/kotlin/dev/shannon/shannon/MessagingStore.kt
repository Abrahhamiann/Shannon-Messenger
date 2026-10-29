package dev.shannon.shannon

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Original thin JNI bridge; upstream owns the complete Olm ratchet. */
internal object MessagingNative {
    init { System.loadLibrary("shannon_messaging_protocol") }
    external fun invoke(request: String): String
}

/** Private SQLite with authenticated-encrypted content/state records. SQLite
 * pages/WAL contain ciphertext, opaque peer indices, counters and timestamps.
 * This is row encryption, not a claim of whole-file SQLCipher encryption. */
internal class MessagingStore(private val appContext: Context, private val fileName: String="shannon_m4_v1.db", private val alias: String="shannon_m4_storage_v1", private val testMode: Boolean=false) : SQLiteOpenHelper(appContext, fileName, null, 2) {
    private val existed = appContext.getDatabasePath(fileName).exists()
    private val key: SecretKey by lazy {
        synchronized(KEY_LOCK) {
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val existing = store.getKey(alias, null)
            if (existing != null) existing as SecretKey
            else {
                check(!existed) { "storage_key_missing" }
                KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                    init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setRandomizedEncryptionRequired(true).build())
                }.generateKey()
            }
        }
    }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE kv (id TEXT PRIMARY KEY, value BLOB NOT NULL)")
        db.execSQL("CREATE TABLE messages (row_id INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE NOT NULL, peer TEXT NOT NULL, created INTEGER NOT NULL, state TEXT NOT NULL, payload BLOB NOT NULL, envelope BLOB, visible INTEGER NOT NULL DEFAULT 1)")
        db.execSQL("CREATE INDEX history_page ON messages(peer,row_id)")
        MessagingActions.schema(db)
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        check(oldVersion==1 && newVersion==2) { "storage_upgrade_unavailable" }
        db.execSQL("ALTER TABLE messages ADD COLUMN visible INTEGER NOT NULL DEFAULT 1")
        MessagingActions.schema(db)
    }
    private fun encode(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    private fun encrypt(id: String, value: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD("shannon.m4.v1|$id".toByteArray(Charsets.UTF_8))
        return byteArrayOf(1) + cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
    }
    private fun decrypt(id: String, value: ByteArray): String {
        check(value.size >= 29 && value[0] == 1.toByte()) { "storage_invalid" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, value.copyOfRange(1,13)))
        cipher.updateAAD("shannon.m4.v1|$id".toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(value.copyOfRange(13,value.size)), Charsets.UTF_8)
    }
    private fun get(db: SQLiteDatabase,id: String): JSONObject? = db.rawQuery("SELECT value FROM kv WHERE id=?", arrayOf(id)).use {
        if(it.moveToFirst()) JSONObject(decrypt("kv|$id",it.getBlob(0))) else null
    }
    private fun put(db: SQLiteDatabase,id: String,value: JSONObject) {
        db.insertWithOnConflict("kv",null,ContentValues().apply { put("id",id);put("value",encrypt("kv|$id",value.toString())) },SQLiteDatabase.CONFLICT_REPLACE).also { check(it!=-1L) }
    }
    // Peer indices are random per device; real account IDs stay in encrypted kv.
    private fun peers(db: SQLiteDatabase) = get(db,"peers") ?: JSONObject()
    private fun peer(db: SQLiteDatabase,account: String): JSONObject? = peers(db).optJSONObject(account)
    private fun protocol(db: SQLiteDatabase,peer: JSONObject? = null): JSONObject {
        val state = get(db,"protocol") ?: error("messaging_not_initialized")
        return JSONObject(state.toString()).put("sessions",peer?.optJSONObject("sessions") ?: JSONObject())
    }
    private fun crypto(request: JSONObject): JSONObject {
        val result=JSONObject(MessagingNative.invoke(request.toString()))
        if(result.has("error")) throw MessagingFailure(result.getString("error"))
        return result
    }
    private fun saveProtocol(db: SQLiteDatabase,result: JSONObject,account: String? = null) {
        val state=result.getJSONObject("state")
        put(db,"protocol",JSONObject().put("account",state.getJSONObject("account")).put("sessions",JSONObject()))
        if(account!=null) {
            val all=peers(db);val p=all.getJSONObject(account)
            p.put("sessions",state.getJSONObject("sessions"))
            if(result.has("session")) p.put("session",result.getString("session"))
            put(db,"peers",all)
        }
        result.remove("state") // Never return private protocol state to Flutter.
    }
    private fun randomID(): String = encode(ByteArray(16).also { SecureRandom().nextBytes(it) })
    private fun owner(db: SQLiteDatabase)=get(db,"owner") ?: error("messaging_not_initialized")
    private fun insertMessage(db: SQLiteDatabase,id: String,peer: JSONObject,body: JSONObject,envelope: JSONObject?,state: String) {
        db.insertOrThrow("messages",null,ContentValues().apply {
            put("id",id);put("peer",peer.getString("index"));put("created",body.getLong("timestamp"));put("state",state)
            put("visible",if(body.optString("kind","text")=="text")1 else 0)
            put("payload",encrypt("message|$id",body.toString()))
            if(envelope!=null)put("envelope",encrypt("envelope|$id",envelope.toString()))
        })
    }
    private fun publicPeer(p: JSONObject): JSONObject = JSONObject(p.toString()).apply { remove("sessions");remove("session");remove("index") }
    private fun actions(db: SQLiteDatabase)=MessagingActions(db,::encrypt,::decrypt)
    private fun send(db: SQLiteDatabase, input: JSONObject, internal: Boolean=false): JSONObject {
        val own=owner(db);val account=input.getString("account");val p=peer(db,account) ?: throw MessagingFailure("peer_untrusted")
        if(p.optBoolean("identity_changed",false)) throw MessagingFailure("identity_changed")
        val binding=p.getJSONObject("binding");val kind=input.optString("kind","text")
        require(kind in setOf("text","capabilities","edit","delete","reaction") || internal && kind=="event_ack")
        if(kind=="capabilities" && p.optBoolean("capabilities_sent",false))return JSONObject().put("skipped",true)
        if(kind in setOf("edit","delete","reaction") || input.has("reply"))check(p.optBoolean("interactions",false)) { "peer_upgrade_required" }
        val body=JSONObject().put("version",if(kind=="text" && !input.has("reply"))1 else 2)
            .put("kind",kind).put("id",randomID()).put("sender",own.getString("account")).put("sender_device",own.getString("device"))
            .put("recipient",account).put("recipient_device",binding.getString("device")).put("timestamp",System.currentTimeMillis())
        if(kind in setOf("text","edit")) {
            val text=input.getString("text")
            require(text.isNotBlank()&&text.toByteArray(Charsets.UTF_8).size<=8000) { "text_size" };body.put("text",text)
        }
        if(kind=="text") {
            if(input.optBoolean("forwarded",false))body.put("forwarded",true)
            if(input.has("reply")) {
                val target=MessagingActions.reference(input.getJSONObject("reply"))
                check(actions(db).original(target,p.getString("index"))!=null) { "message_unavailable" }
                body.put("reply",input.getJSONObject("reply"))
            }
        } else if(kind=="capabilities")body.put("capabilities",JSONArray().put("interactions.v1"))
        else {
            val target=input.getJSONObject("target");val reference=MessagingActions.reference(target)
            require(target.getString("sender_device") in setOf(own.getString("device"),binding.getString("device")))
            body.put("target",target)
            if(kind!="event_ack") {
                val original=actions(db).original(reference,p.getString("index")) ?: throw MessagingFailure("message_unavailable")
                check(!original.optBoolean("deleted",false) && !actions(db).effects(reference,p.getString("index")).any {it.getString("kind")=="delete"}) { "message_deleted" }
                body.put("revision",actions(db).nextRevision(reference,p.getString("index"),kind,own.getString("device")))
                if(kind=="reaction")body.put("emoji",input.getString("emoji"))
            }
        }
        val req=JSONObject().put("op","encrypt").put("state",protocol(db,p)).put("peer_curve",binding.getString("curve")).put("plaintext",body.toString())
        if(p.has("session"))req.put("session",p.getString("session"))
        if(input.has("prekey"))req.put("prekey",input.getString("prekey"))
        val result=crypto(req);val id=body.getString("id")
        val envelope=JSONObject().put("version",1).put("id",id).put("recipient",account).put("recipient_device",binding.getString("device"))
            .put("suite","olm.v1").put("type",result.getInt("type")).put("ciphertext",result.getString("ciphertext"))
        saveProtocol(db,result,account)
        insertMessage(db,"${own.getString("device")}:$id",p,body,envelope,"queued")
        if(kind=="text") {val all=peers(db);all.getJSONObject(account).put("chat_hidden",false);put(db,"peers",all)}
        if(kind in setOf("edit","delete","reaction"))actions(db).record(body,p.getString("index"))
        if(kind=="capabilities") {
            val all=peers(db);all.getJSONObject(account).put("capabilities_sent",true);put(db,"peers",all)
        }
        return JSONObject().put("id",id)
    }
    fun invoke(request: String): String {
        if(request.length>200000) throw MessagingFailure("request_size")
        val input=JSONObject(request);val op=input.getString("op")
        // Obtain the wrapping key before creating a new database file. A
        // missing key for an existing DB never causes silent key regeneration.
        key
        val db=writableDatabase
        db.beginTransaction()
        var rejection: String? = null
        try {
            val output=when(op) {
                "initialize" -> {
                    val account=input.getString("account");val device=input.getString("device")
                    require(account.matches(Regex("shn1_[A-Za-z0-9_-]{43}")) && device.matches(Regex("dev1_[A-Za-z0-9_-]{43}")))
                    val current=get(db,"owner")
                    check(current==null||(current.getString("account")==account&&current.getString("device")==device)) { "storage_owner_mismatch" }
                    if(current==null)put(db,"owner",JSONObject().put("account",account).put("device",device))
                    val state=get(db,"protocol")
                    if(current!=null&&state==null)throw MessagingFailure("state_missing")
                    val result=crypto(JSONObject().put("op","initialize").put("state",state))
                    saveProtocol(db,result);result
                }
                "publish","mark_published" -> {
                    val own=owner(db)
                    val context="${own.getString("account")}\n${own.getString("device")}\n1"
                    val req=JSONObject().put("op",op).put("context",context).put("state",protocol(db))
                    if(input.has("needed"))req.put("needed",input.getInt("needed"))
                    val result=crypto(req)
                    saveProtocol(db,result);result
                }
                "peer" -> peer(db,input.getString("account"))?.let { publicPeer(it) } ?: JSONObject()
                "trust" -> {
                    val binding=input.getJSONObject("binding");val account=binding.getString("account")
                    val all=peers(db);val previous=all.optJSONObject(account)
                    if(previous!=null) {
                        val old=previous.getJSONObject("binding")
                        if(previous.optBoolean("identity_changed",false) || listOf("device","curve","signing","epoch","root_key","device_key").any {old.get(it)!=binding.get(it)}) {
                            // Persist a fail-closed latch before reporting rejection.
                            // Restart or a directory rollback must not forget a change.
                            previous.put("identity_changed",true)
                            put(db,"peers",all)
                            rejection="identity_changed"
                        }
                        if(input.has("label")) {previous.put("label",input.getString("label").take(96));put(db,"peers",all)}
                        publicPeer(previous)
                    } else {
                        check(all.length()<500) { "peer_limit" }
                        val p=JSONObject().put("binding",binding).put("verified",false).put("label",input.optString("label",account))
                            .put("index",randomID()).put("sessions",JSONObject())
                        all.put(account,p);put(db,"peers",all);publicPeer(p)
                    }
                }
                "verify" -> {
                    val all=peers(db);val p=all.getJSONObject(input.getString("account"))
                    if(input.getBoolean("verified") && p.optBoolean("identity_changed",false)) throw MessagingFailure("identity_changed")
                    p.put("verified",input.getBoolean("verified"));put(db,"peers",all);publicPeer(p)
                }
                "send" -> send(db,input)
                "send_many" -> {
                    val items=input.getJSONArray("items");require(items.length() in 1..100)
                    val result=JSONArray()
                    for(i in 0 until items.length()) result.put(send(db,JSONObject(items.getJSONObject(i).toString()).put("account",input.getString("account"))))
                    JSONObject().put("items",result)
                }
                "chat_preferences","delete_chat","local_delete_many" -> {
                    val account=input.getString("account");val all=peers(db)
                    val p=all.getJSONObject(account);val index=p.getString("index")
                    if(op=="chat_preferences") {
                        for(key in listOf("chat_pinned","archived")) if(input.has(key))p.put(key,input.getBoolean(key))
                    } else {
                        val targets=mutableListOf<String>()
                        if(op=="delete_chat") {
                            db.rawQuery("SELECT id FROM messages WHERE peer=? AND visible=1",arrayOf(index)).use {while(it.moveToNext())targets.add(it.getString(0))}
                            p.put("chat_hidden",true).put("chat_pinned",false)
                        } else {
                            val refs=input.getJSONArray("targets");require(refs.length() in 1..100)
                            for(i in 0 until refs.length())targets.add(MessagingActions.reference(refs.getJSONObject(i)))
                        }
                        for(target in targets)actions(db).redact(target,index,true)
                        if(p.optString("pinned_message") in targets)p.remove("pinned_message")
                    }
                    put(db,"peers",all);JSONObject()
                }
                "receive" -> {
                    val own=owner(db);val envelope=input.getJSONObject("envelope");val account=envelope.getString("sender")
                    val p=peer(db,account) ?: throw MessagingFailure("peer_untrusted");val binding=p.getJSONObject("binding")
                    require(envelope.getString("sender_device")==binding.getString("device")&&envelope.getString("suite")=="olm.v1"&&envelope.getInt("version")==1)
                    val id="${binding.getString("device")}:${envelope.getString("id")}"
                    val exists=db.rawQuery("SELECT 1 FROM messages WHERE id=?",arrayOf(id)).use {it.moveToFirst()}
                    if(exists)JSONObject().put("duplicate",true) else {
                        val result=crypto(JSONObject().put("op","decrypt").put("state",protocol(db,p)).put("peer_curve",binding.getString("curve"))
                            .put("type",envelope.getInt("type")).put("ciphertext",envelope.getString("ciphertext")))
                        val body=JSONObject(result.getString("plaintext"))
                        val kind=body.optString("kind","text")
                        require(body.getInt("version") in 1..2 && (body.getInt("version")==2 || kind=="text") && body.getString("id")==envelope.getString("id")&&body.getString("sender")==account&&body.getString("sender_device")==binding.getString("device")
                            &&body.getString("recipient")==own.getString("account")&&body.getString("recipient_device")==own.getString("device")) { "routing_mismatch" }
                        require(kind in setOf("text","capabilities","edit","delete","reaction","event_ack")) { "unsupported_event" }
                        if(kind in setOf("text","edit")) require(body.getString("text").isNotBlank()&&body.getString("text").toByteArray(Charsets.UTF_8).size<=8000) { "text_size" }
                        if(body.has("reply")) {
                            val reply=body.getJSONObject("reply");MessagingActions.reference(reply)
                            require(reply.getString("sender_device") in setOf(own.getString("device"),binding.getString("device")))
                        }
                        saveProtocol(db,result,account);insertMessage(db,id,p,body,null,"received")
                        if(kind=="text") {val all=peers(db);all.getJSONObject(account).put("chat_hidden",false);put(db,"peers",all)}
                        var flush=false
                        if(kind=="capabilities") {
                            val caps=body.getJSONArray("capabilities");require(caps.length()==1 && caps.getString(0)=="interactions.v1")
                            val all=peers(db);all.getJSONObject(account).put("interactions",true);put(db,"peers",all)
                            if(!all.getJSONObject(account).optBoolean("capabilities_sent",false)) {
                                send(db,JSONObject().put("account",account).put("kind","capabilities"),true);flush=true
                            }
                        } else if(kind=="event_ack") {
                            val target=body.getJSONObject("target");val targetID=MessagingActions.reference(target)
                            require(target.getString("sender_device")==own.getString("device"))
                            db.rawQuery("SELECT payload FROM messages WHERE id=? AND peer=? AND visible=0",arrayOf(targetID,p.getString("index"))).use {
                                require(it.moveToFirst()) { "unknown_event_ack" }
                                val event=JSONObject(decrypt("message|$targetID",it.getBlob(0)))
                                require(event.getString("kind") in setOf("edit","delete","reaction"))
                            }
                            db.update("messages",ContentValues().apply{put("state","applied");putNull("envelope")},"id=?",arrayOf(targetID))
                        } else if(kind!="text") {
                            check(p.optBoolean("interactions",false)) { "peer_upgrade_required" }
                            val target=body.getJSONObject("target");MessagingActions.reference(target)
                            require(target.getString("sender_device") in setOf(own.getString("device"),binding.getString("device")))
                            actions(db).record(body,p.getString("index"))
                            send(db,JSONObject().put("account",account).put("kind","event_ack").put("target",JSONObject().put("id",body.getString("id")).put("sender_device",binding.getString("device"))),true)
                            flush=true
                        } else if(actions(db).effects(id,p.getString("index")).any{it.getString("kind")=="delete"}) actions(db).redact(id,p.getString("index"),false)
                        JSONObject().put("duplicate",false).put("needs_flush",flush)
                    }
                }
                "outbox" -> {
                    val result=JSONArray()
                    db.rawQuery("SELECT id,envelope,created FROM messages WHERE state='queued' AND envelope IS NOT NULL ORDER BY row_id LIMIT 50",null).use {
                        while(it.moveToNext())result.put(JSONObject(decrypt("envelope|${it.getString(0)}",it.getBlob(1))).put("local_created",it.getLong(2)))
                    };JSONObject().put("items",result)
                }
                "state" -> {
                    val own=owner(db);val id="${own.getString("device")}:${input.getString("id")}";val state=input.getString("state")
                    require(state in listOf("queued","accepted","failed","expired"))
                    db.update("messages",ContentValues().apply{put("state",state);if(state=="accepted")putNull("envelope")},"id=? AND state!='applied'",arrayOf(id));JSONObject()
                }
                "local_delete","pin","message" -> {
                    val account=input.getString("account");val p=peer(db,account) ?: throw MessagingFailure("peer_untrusted")
                    val target=MessagingActions.reference(input.getJSONObject("target"));val all=peers(db)
                    if(op=="local_delete") {
                        actions(db).redact(target,p.getString("index"),true)
                        if(all.getJSONObject(account).optString("pinned_message")==target) {all.getJSONObject(account).remove("pinned_message");put(db,"peers",all)}
                        JSONObject()
                    } else if(op=="pin") {
                        check(actions(db).original(target,p.getString("index"))!=null) { "message_unavailable" }
                        if(input.getBoolean("value"))all.getJSONObject(account).put("pinned_message",target) else all.getJSONObject(account).remove("pinned_message")
                        put(db,"peers",all);JSONObject()
                    } else {
                        val body=actions(db).original(target,p.getString("index"))
                        if(body==null) JSONObject() else actions(db).project(target,body,p.getString("index"),owner(db).getString("account"))
                    }
                }
                "history","around" -> {
                    val account=input.getString("account");val p=peer(db,account)
                    val result=JSONArray()
                    var before=input.optLong("before",Long.MAX_VALUE)
                    if(op=="around" && p!=null) {
                        val target=MessagingActions.reference(input.getJSONObject("target"))
                        before=db.rawQuery("SELECT row_id FROM messages WHERE id=? AND peer=? AND visible=1",arrayOf(target,p.getString("index"))).use {if(it.moveToFirst())it.getLong(0)+1 else 0}
                    }
                    if(p!=null)db.rawQuery("SELECT row_id,id,state,payload FROM messages WHERE peer=? AND visible=1 AND row_id<? ORDER BY row_id DESC LIMIT 50",arrayOf(p.getString("index"),before.toString())).use {
                        while(it.moveToNext()){
                            val body=JSONObject(decrypt("message|${it.getString(1)}",it.getBlob(3)))
                            result.put(actions(db).project(it.getString(1),body,p.getString("index"),owner(db).getString("account")).put("local_row",it.getLong(0)).put("state",it.getString(2)))
                        }
                    };JSONObject().put("items",result)
                }
                "conversations" -> {
                    val result=JSONArray();val all=peers(db)
                    for(account in all.keys()){
                        val p=all.getJSONObject(account)
                        if(p.optBoolean("chat_hidden",false))continue
                        db.rawQuery("SELECT id,state,payload FROM messages WHERE peer=? AND visible=1 ORDER BY row_id DESC LIMIT 1",arrayOf(p.getString("index"))).use {
                            if(it.moveToFirst()) result.put(publicPeer(p).put("last",actions(db).project(it.getString(0),JSONObject(decrypt("message|${it.getString(0)}",it.getBlob(2))),p.getString("index"),owner(db).getString("account")).put("state",it.getString(1))))
                        }
                    };JSONObject().put("items",result)
                }
                "validation_scan" -> {
                    check(testMode)
                    val marker=input.getString("marker");require(marker.startsWith("M4_TEST_")&&marker.length<=128)
                    val needle=marker.toByteArray(Charsets.UTF_8)
                    var found=false
                    for(suffix in listOf("","-wal","-journal")) {
                        val file=java.io.File(appContext.getDatabasePath(fileName).path+suffix)
                        if(file.exists()) {
                            check(file.length()<=4*1024*1024)
                            val data=file.readBytes()
                            for(i in 0..data.size-needle.size) {
                                if(needle.indices.all {data[i+it]==needle[it]}) {found=true;break}
                            }
                        }
                    }
                    JSONObject().put("plaintext_found",found)
                }
                else -> throw MessagingFailure("operation_unavailable")
            }
            if(input.optBoolean("fail_before_commit",false)) {
                check(testMode)
                throw MessagingFailure("injected_write_failure")
            }
            db.setTransactionSuccessful()
            if(rejection!=null) throw MessagingFailure(rejection!!)
            return output.toString()
        } finally { db.endTransaction() }
    }
    companion object { private val KEY_LOCK=Any() }
}
internal class MessagingFailure(val code: String): Exception(code)
