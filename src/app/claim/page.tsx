"use client";

import { FormEvent, useEffect, useState } from "react";

type Claim = { id:string; email:string; first_name:string; last_name:string; imported_profile:Record<string,unknown> };

export default function ClaimPage() {
  const [claim,setClaim]=useState<Claim|null>(null);
  const [message,setMessage]=useState("Checking your private invitation…");
  const [busy,setBusy]=useState(true);
  useEffect(()=>{
    const token=new URLSearchParams(location.search).get("token");
    if(!token){setMessage("This claim link is incomplete.");setBusy(false);return;}
    fetch("/api/claims/verify",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({token})})
      .then(async r=>({ok:r.ok,body:await r.json()})).then(({ok,body})=>{if(!ok)throw new Error(body.error);setClaim(body.claim);setMessage("");})
      .catch(e=>setMessage(e.message)).finally(()=>setBusy(false));
  },[]);
  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault(); setBusy(true); setMessage("");
    const form=new FormData(event.currentTarget);
    const url=process.env.NEXT_PUBLIC_SUPABASE_URL; const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if(!url||!key){setMessage("Account activation is waiting for the Supabase public keys to be configured.");setBusy(false);return;}
    const response=await fetch(`${url}/auth/v1/signup`,{method:"POST",headers:{apikey:key,"Content-Type":"application/json"},body:JSON.stringify({email:claim!.email,password:String(form.get("password")||""),data:{first_name:form.get("first_name"),last_name:form.get("last_name"),legacy_claim_id:claim!.id,email_opt_in:form.get("email_opt_in")==="on",directory_visible:form.get("directory_visible")==="on"}})});
    const result=await response.json();
    setMessage(response.ok?"Your account was created. Check your email to verify it, then sign in to finish activating your imported membership.":result.msg||result.error_description||"Account activation could not be completed.");
    setBusy(false);
  }
  return <main className="claim-page"><section className="claim-card"><p className="eyebrow">EFF CONNECT · LEGACY MEMBER WELCOME</p><h1>Claim your membership profile.</h1>{message&&<div className="claim-message">{message}</div>}{claim&&<form onSubmit={submit}><p>We found the membership record for <strong>{claim.email}</strong>. Review your name, choose a password, and confirm your preferences. Your existing membership will be connected after email verification—no duplicate record will be created.</p><label>First name<input name="first_name" defaultValue={claim.first_name} required/></label><label>Last name<input name="last_name" defaultValue={claim.last_name} required/></label><label>Create password<input name="password" type="password" minLength={10} required/></label><label className="check"><input name="agreements" type="checkbox" required/> I agree to review and accept the current membership agreements after sign-in.</label><label className="check"><input name="email_opt_in" type="checkbox" defaultChecked/> Send me helpful EFF member updates by email.</label><label className="check"><input name="directory_visible" type="checkbox"/> Show my approved profile fields in the private member directory.</label><button className="primary" disabled={busy}>{busy?"Activating…":"Create account & continue →"}</button></form>}</section></main>;
}
