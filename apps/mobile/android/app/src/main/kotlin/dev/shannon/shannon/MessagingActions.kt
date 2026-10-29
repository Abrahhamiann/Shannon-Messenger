package dev.shannon.shannon

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject

/** Application events inside authenticated Olm plaintext; never a crypto engine. */
internal class MessagingActions(
    private val db: SQLiteDatabase,
    private val seal: (String,String)->ByteArray,
    private val open: (String,ByteArray)->String
) {
    companion object {
        val reactions = setOf("👍", "❤️", "😂", "😮", "😢", "🔥")
        fun schema(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE effects (id TEXT PRIMARY KEY, peer TEXT NOT NULL, target TEXT NOT NULL, payload BLOB NOT NULL)")
            db.execSQL("CREATE INDEX effects_target ON effects(peer,target)")
        }
        fun reference(value: JSONObject): String {
            val device=value.getString("sender_device"); val id=value.getString("id")
            require(device.matches(Regex("dev1_[A-Za-z0-9_-]{43}")) && id.matches(Regex("[A-Za-z0-9_-]{22}"))) { "invalid_reference" }
            return "$device:$id"
        }
    }
    fun original(target: String, peer: String): JSONObject? = db.rawQuery(
        "SELECT payload FROM messages WHERE id=? AND peer=? AND visible=1", arrayOf(target,peer)
    ).use { if(it.moveToFirst()) JSONObject(open("message|$target",it.getBlob(0))) else null }

    fun effects(target: String, peer: String): List<JSONObject> {
        val rows=mutableListOf<JSONObject>()
        db.rawQuery("SELECT e.id,e.payload,m.state FROM effects e JOIN messages m ON m.id=e.id WHERE e.peer=? AND e.target=? LIMIT 257",arrayOf(peer,target)).use {
            while(it.moveToNext()) rows.add(JSONObject(open("effect|${it.getString(0)}",it.getBlob(1))).put("delivery",it.getString(2)))
        }
        check(rows.size<=256) { "interaction_limit" }
        return rows
    }
    fun nextRevision(target: String, peer: String, kind: String, actor: String): Int =
        1+(effects(target,peer).filter {it.getString("kind")==kind && it.getString("sender_device")==actor}.maxOfOrNull {it.getInt("revision")} ?: 0)

    fun record(body: JSONObject, peer: String) {
        val target=reference(body.getJSONObject("target"))
        val kind=body.getString("kind")
        require(kind in setOf("edit","delete","reaction"))
        require(body.getInt("revision") in 1..Int.MAX_VALUE-1)
        if(kind!="reaction") require(body.getString("sender_device")==body.getJSONObject("target").getString("sender_device")) { "not_message_owner" }
        if(kind=="edit") require(body.getString("text").isNotBlank() && body.getString("text").toByteArray(Charsets.UTF_8).size<=8000)
        if(kind=="reaction") require(body.getString("emoji").isEmpty() || body.getString("emoji") in reactions)
        check(effects(target,peer).size<256) { "interaction_limit" }
        val id="${body.getString("sender_device")}:${body.getString("id")}"
        db.insertOrThrow("effects",null,ContentValues().apply {
            put("id",id);put("peer",peer);put("target",target);put("payload",seal("effect|$id",body.toString()))
        })
        if(kind=="delete") redact(target,peer,false)
    }
    fun redact(target: String, peer: String, local: Boolean) {
        val body=original(target,peer) ?: return
        body.put("text","").remove("reply")
        body.put(if(local) "local_deleted" else "deleted",true)
        db.update("messages",ContentValues().apply { put("payload",seal("message|$target",body.toString()));if(local)put("visible",2) },"id=? AND peer=?",arrayOf(target,peer))
    }
    fun project(id: String, body: JSONObject, peer: String, owner: String): JSONObject {
        val events=effects(id,peer)
        val deleted=events.filter {it.getString("kind")=="delete"}.maxWithOrNull(compareBy<JSONObject> {it.getInt("revision")}.thenBy {it.getString("id")})
        val edit=events.filter {it.getString("kind")=="edit"}.maxWithOrNull(compareBy<JSONObject> {it.getInt("revision")}.thenBy {it.getString("id")})
        if(deleted!=null || body.optBoolean("deleted",false)) {
            body.put("text","").put("deleted",true).remove("reply")
            if(deleted!=null)body.put("change_state",deleted.getString("delivery"))
        } else if(edit!=null) {
            body.put("text",edit.getString("text")).put("edited",true).put("change_state",edit.getString("delivery"))
        }
        val reactions=JSONArray()
        if(!body.optBoolean("deleted",false)) events.filter {it.getString("kind")=="reaction"}.groupBy {it.getString("sender_device")}.values.forEach { changes ->
            val latest=changes.maxWithOrNull(compareBy<JSONObject> {it.getInt("revision")}.thenBy {it.getString("id")})!!
            if(latest.getString("emoji").isNotEmpty())reactions.put(JSONObject().put("emoji",latest.getString("emoji")).put("own",latest.getString("sender")==owner).put("state",latest.getString("delivery")))
        }
        body.put("reactions",reactions)
        val reply=body.optJSONObject("reply")
        if(reply!=null) {
            val target=reference(reply)
            val source=original(target,peer)
            val gone=source==null || source.optBoolean("deleted",false) || effects(target,peer).any {it.getString("kind")=="delete"}
            body.put("reply_preview",JSONObject().put("available",!gone).put("own",source?.optString("sender")==owner).put("text",if(gone)"Message unavailable" else projectWithoutReply(target,source!!,peer).take(160)))
        }
        return body
    }
    private fun projectWithoutReply(id: String, body: JSONObject, peer: String): String {
        val edit=effects(id,peer).filter {it.getString("kind")=="edit"}.maxWithOrNull(compareBy<JSONObject> {it.getInt("revision")}.thenBy {it.getString("id")})
        return edit?.getString("text") ?: body.optString("text")
    }
}
