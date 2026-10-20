import {NextRequest,NextResponse} from 'next/server'
import {createClient} from '@supabase/supabase-js'
export async function POST(req:NextRequest){
 try{
  const token=req.headers.get('authorization')?.replace(/^Bearer /,'');if(!token)return NextResponse.json({error:'Não autorizado'},{status:401})
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,service=process.env.SUPABASE_SERVICE_ROLE_KEY
  if(!service)return NextResponse.json({error:'Servidor não configurado'},{status:503})
  const client=createClient(url,anon),admin=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}})
  const {data:{user},error}=await client.auth.getUser(token);if(error||!user)return NextResponse.json({error:'Sessão inválida'},{status:401})
  const {data:profile}=await admin.from('profiles').select('role,active').eq('id',user.id).single()
  if(profile?.role!=='admin'||!profile.active)return NextResponse.json({error:'Sem permissão'},{status:403})
  const body=await req.json();const email=String(body.email||'').trim().toLowerCase(),name=String(body.name||'').trim(),role=String(body.role||'')
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!name||name.length>120||!['doctor','receptionist','admin'].includes(role))return NextResponse.json({error:'Dados inválidos'},{status:400})
  const {data:invited,error:inviteError}=await admin.auth.admin.inviteUserByEmail(email)
  if(inviteError||!invited.user)return NextResponse.json({error:inviteError?.message||'Falha no convite'},{status:400})
  const {error:profileError}=await admin.from('profiles').update({name,role,active:true}).eq('id',invited.user.id)
  if(profileError)return NextResponse.json({error:'Convite enviado, mas perfil por configurar. Contacta o administrador.'},{status:500})
  return NextResponse.json({ok:true})
 }catch{return NextResponse.json({error:'Erro ao processar pedido'},{status:500})}
}
