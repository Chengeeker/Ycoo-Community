package ycoo.net.php

import android.content.Context
import android.graphics.Bitmap
import android.opengl.*
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

// The same bundled shader runs on GLES for Android versions without RuntimeShader.
object LegacyGlass {
    private val dispatcher=Executors.newSingleThreadExecutor{r->Thread(r,"glass-render").apply{isDaemon=true}}.asCoroutineDispatcher()
    private var display:EGLDisplay?=null
    private var surface:EGLSurface?=null
    private var context:EGLContext?=null
    private val programs=mutableMapOf<String,Int>()
    private fun initialize(){
        if(display!=null)return
        val d=EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);check(d!=EGL14.EGL_NO_DISPLAY)
        check(EGL14.eglInitialize(d,IntArray(2),0,IntArray(2),1))
        val configs=arrayOfNulls<EGLConfig>(1);val count=IntArray(1)
        check(EGL14.eglChooseConfig(d,intArrayOf(EGL14.EGL_RENDERABLE_TYPE,0x40,EGL14.EGL_SURFACE_TYPE,EGL14.EGL_PBUFFER_BIT,EGL14.EGL_RED_SIZE,8,EGL14.EGL_GREEN_SIZE,8,EGL14.EGL_BLUE_SIZE,8,EGL14.EGL_ALPHA_SIZE,8,EGL14.EGL_NONE),0,configs,0,1,count,0)&&count[0]>0)
        val c=EGL14.eglCreateContext(d,configs[0],EGL14.EGL_NO_CONTEXT,intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION,3,EGL14.EGL_NONE),0)
        val s=EGL14.eglCreatePbufferSurface(d,configs[0],intArrayOf(EGL14.EGL_WIDTH,1,EGL14.EGL_HEIGHT,1,EGL14.EGL_NONE),0)
        check(EGL14.eglMakeCurrent(d,s,s,c));display=d;surface=s;context=c
    }
    private fun shader(type:Int,source:String):Int {val id=GLES30.glCreateShader(type);GLES30.glShaderSource(id,source);GLES30.glCompileShader(id);val status=IntArray(1);GLES30.glGetShaderiv(id,GLES30.GL_COMPILE_STATUS,status,0);check(status[0]!=0){GLES30.glGetShaderInfoLog(id)};return id}
    private fun program(app:Context,name:String):Int=programs.getOrPut(name){
        val vertex=shader(GLES30.GL_VERTEX_SHADER,"#version 300 es\nvoid main(){vec2 p=vec2((gl_VertexID==1||gl_VertexID==3)?1.0:-1.0,gl_VertexID>=2?1.0:-1.0);gl_Position=vec4(p,0.0,1.0);}")
        val fragment=shader(GLES30.GL_FRAGMENT_SHADER,app.assets.open("glass/$name.frag").bufferedReader().use{it.readText()})
        val id=GLES30.glCreateProgram();GLES30.glAttachShader(id,vertex);GLES30.glAttachShader(id,fragment);GLES30.glLinkProgram(id);GLES30.glDeleteShader(vertex);GLES30.glDeleteShader(fragment)
        val status=IntArray(1);GLES30.glGetProgramiv(id,GLES30.GL_LINK_STATUS,status,0);check(status[0]!=0){GLES30.glGetProgramInfoLog(id)};id
    }
    suspend fun render(app:Context,name:String,bitmap:Bitmap,uniforms:Map<String,FloatArray>):Bitmap=withContext(dispatcher){
        initialize();val p=program(app,name);val textures=IntArray(2);val frame=IntArray(1)
        GLES30.glGenTextures(2,textures,0);GLES30.glGenFramebuffers(1,frame,0)
        try{
            GLES30.glActiveTexture(GLES30.GL_TEXTURE0);GLES30.glBindTexture(GLES30.GL_TEXTURE_2D,textures[0]);textureParameters();GLUtils.texImage2D(GLES30.GL_TEXTURE_2D,0,bitmap,0)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D,textures[1]);textureParameters();GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D,0,GLES30.GL_RGBA,bitmap.width,bitmap.height,0,GLES30.GL_RGBA,GLES30.GL_UNSIGNED_BYTE,null)
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER,frame[0]);GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER,GLES30.GL_COLOR_ATTACHMENT0,GLES30.GL_TEXTURE_2D,textures[1],0);check(GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)==GLES30.GL_FRAMEBUFFER_COMPLETE)
            GLES30.glUseProgram(p);GLES30.glViewport(0,0,bitmap.width,bitmap.height);GLES30.glBindTexture(GLES30.GL_TEXTURE_2D,textures[0]);GLES30.glUniform1i(GLES30.glGetUniformLocation(p,if(name=="gallery_glass_button")"u_texture_input"else "uBackgroundTexture"),0)
            GLES30.glUniform2f(GLES30.glGetUniformLocation(p,"renderSize"),bitmap.width.toFloat(),bitmap.height.toFloat())
            uniforms.forEach{(key,v)->val loc=GLES30.glGetUniformLocation(p,key);when(v.size){1->GLES30.glUniform1fv(loc,1,v,0);2->GLES30.glUniform2fv(loc,1,v,0);3->GLES30.glUniform3fv(loc,1,v,0);4->GLES30.glUniform4fv(loc,1,v,0)}}
            GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP,0,4)
            val bytes=ByteBuffer.allocateDirect(bitmap.width*bitmap.height*4).order(ByteOrder.nativeOrder());GLES30.glReadPixels(0,0,bitmap.width,bitmap.height,GLES30.GL_RGBA,GLES30.GL_UNSIGNED_BYTE,bytes)
            check(GLES30.glGetError()==GLES30.GL_NO_ERROR){"玻璃图层渲染失败"}
            val pixels=IntArray(bitmap.width*bitmap.height);for(y in 0 until bitmap.height)for(x in 0 until bitmap.width){val index=((bitmap.height-1-y)*bitmap.width+x)*4;val alpha=bytes[index+3].toInt()and 255
                fun straight(channel:Int)=if(alpha==0)0 else ((bytes[index+channel].toInt()and 255)*255/alpha).coerceAtMost(255)
                pixels[y*bitmap.width+x]=(alpha shl 24)or(straight(0)shl 16)or(straight(1)shl 8)or straight(2)
            }
            Bitmap.createBitmap(pixels,bitmap.width,bitmap.height,Bitmap.Config.ARGB_8888)
        }finally{GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER,0);GLES30.glDeleteFramebuffers(1,frame,0);GLES30.glDeleteTextures(2,textures,0)}
    }
    private fun textureParameters(){GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,GLES30.GL_TEXTURE_MIN_FILTER,GLES30.GL_LINEAR);GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,GLES30.GL_TEXTURE_MAG_FILTER,GLES30.GL_LINEAR);GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,GLES30.GL_TEXTURE_WRAP_S,GLES30.GL_CLAMP_TO_EDGE);GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,GLES30.GL_TEXTURE_WRAP_T,GLES30.GL_CLAMP_TO_EDGE)}
}
