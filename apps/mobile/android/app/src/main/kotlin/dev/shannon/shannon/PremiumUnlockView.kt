package dev.shannon.shannon

import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.widget.*

/** Opaque native security cover. Only the existing AppLock can dismiss it. */
internal class PremiumUnlockView(context: Context, dark: Boolean, animate: Boolean=true, unlock: ()->Unit): FrameLayout(context) {
    private fun dp(value: Int)=(value*resources.displayMetrics.density).toInt()
    private val textColor=Color.parseColor(if(dark)"#F3F6FA" else "#132033")
    private val secondary=Color.parseColor(if(dark)"#98A7B9" else "#526277")
    private val action: Button
    private val status: TextView
    init {
        setBackgroundColor(Color.parseColor(if(dark)"#0B1118" else "#F5F8FC"))
        isClickable=true;isFocusableInTouchMode=true
        importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_YES
        val scroll=ScrollView(context).apply {isFillViewport=true;clipToPadding=false;setPadding(dp(28),dp(32),dp(28),dp(32))}
        val content=LinearLayout(context).apply {orientation=LinearLayout.VERTICAL;gravity=Gravity.CENTER;setPadding(0,dp(24),0,dp(24))}
        val logo=FrameLayout(context)
        logo.addView(object: View(context) {
            private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
            override fun onDraw(canvas: Canvas) {
                paint.shader=RadialGradient(width/2f,height/2f,width/2f,intArrayOf(Color.parseColor(if(dark)"#243D82F6" else "#333B82F6"),Color.TRANSPARENT),null,Shader.TileMode.CLAMP)
                canvas.drawCircle(width/2f,height/2f,width/2f,paint)
            }
        },LayoutParams(-1,-1))
        logo.addView(ImageView(context).apply {setImageResource(R.drawable.shannon_ribbon);contentDescription="Shannon";scaleType=ImageView.ScaleType.FIT_CENTER},LayoutParams(dp(108),dp(108),Gravity.CENTER))
        content.addView(logo,LinearLayout.LayoutParams(dp(224),dp(224)))
        fun text(value: String,size: Float,color: Int,bold: Boolean=false)=TextView(context).apply {
            this.text=value;textSize=size;setTextColor(color);gravity=Gravity.CENTER
            typeface=try {Typeface.create(Typeface.createFromAsset(context.assets,"flutter_assets/assets/fonts/Manrope[wght].ttf"),if(bold)Typeface.BOLD else Typeface.NORMAL)}catch(_:Exception){Typeface.create("sans-serif",if(bold)Typeface.BOLD else Typeface.NORMAL)}
        }
        val title=text("Unlock Shannon",28f,textColor,true).apply {if(android.os.Build.VERSION.SDK_INT>=28)setAccessibilityHeading(true)}
        content.addView(title,LinearLayout.LayoutParams(-1,-2).apply {bottomMargin=dp(12)})
        content.addView(text("Your conversations stay private.",16f,secondary),LinearLayout.LayoutParams(-1,-2).apply {bottomMargin=dp(38)})
        action=Button(context).apply {
            text="Unlock";textSize=16f;isAllCaps=false;setTextColor(Color.WHITE);minHeight=dp(54);minimumHeight=dp(54)
            typeface=Typeface.create("sans-serif-medium",Typeface.NORMAL)
            val shape=GradientDrawable(GradientDrawable.Orientation.TL_BR,intArrayOf(Color.parseColor("#3B82F6"),Color.parseColor("#2563EB"))).apply {cornerRadius=dp(17).toFloat()}
            background=RippleDrawable(ColorStateList.valueOf(0x30FFFFFF),shape,null)
            val lock=context.getDrawable(android.R.drawable.ic_lock_lock)!!.mutate().apply {setTint(Color.WHITE);setBounds(0,0,dp(20),dp(20))}
            setCompoundDrawablesRelative(lock,null,null,null);compoundDrawablePadding=dp(10);gravity=Gravity.CENTER
            setPadding(dp(24),dp(14),dp(24),dp(14))
            contentDescription="Unlock with fingerprint or device screen lock"
            setOnClickListener {unlock()}
        }
        content.addView(action,LinearLayout.LayoutParams(-1,-2).apply {leftMargin=dp(16);rightMargin=dp(16)})
        status=text("Use your fingerprint or device screen lock.",13f,secondary).apply {accessibilityLiveRegion=View.ACCESSIBILITY_LIVE_REGION_POLITE}
        content.addView(status,LinearLayout.LayoutParams(-1,-2).apply {topMargin=dp(20)})
        scroll.addView(content,FrameLayout.LayoutParams(-1,-1));addView(scroll,LayoutParams(-1,-1))
        setOnApplyWindowInsetsListener {_,insets -> scroll.setPadding(dp(28),dp(32)+insets.systemWindowInsetTop,dp(28),dp(32)+insets.systemWindowInsetBottom);insets}
        if(animate && ValueAnimator.areAnimatorsEnabled()) {content.alpha=0f;content.translationY=dp(8).toFloat();content.animate().alpha(1f).translationY(0f).setDuration(180).start()}
    }
    fun busy(value: Boolean) {action.isEnabled=!value;action.alpha=if(value).65f else 1f;action.text=if(value)"Unlocking…" else "Unlock"}
    fun retry() {status.text="Unlock when you’re ready. Your conversations stay protected."}
}
