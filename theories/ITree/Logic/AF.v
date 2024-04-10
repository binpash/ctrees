From Coq Require Import
  Basics
  Init.Wf
  Classes.Morphisms.

From Coinduction Require Import
  coinduction lattice.

From ExtLib Require Import
  Structures.Monad
  Data.Monads.StateMonad.

From CTree Require Import
  Events.Core
  ITree.Core
  ITree.Equ  
  ITree.Logic.Trans
  ITree.Logic.CanStep
  Logic.Ctl
  Logic.Kripke.

Set Implicit Arguments.
Generalizable All Variables.

Import ITreeNotations CtlNotations.
Local Open Scope ctl_scope.
Local Open Scope itree_scope.
  
(*| CTL logic lemmas on c/itrees |*)
Section BasicLemmas.
  Context {E: Type} {HE: Encode E} {X: Type} (φ: X -> World E -> Prop).

  Lemma af_tau: forall (t: itree E X) w φ,
      <( t, w |= AF now φ )> -> 
      <( {Tau t}, w |= AF (now φ) )>.
  Proof.
    intros.
    unfold entailsF in H.
    induction H.
    - now next; left.
    - Opaque entailsF.
      destruct H0, H1; clear H H1.
      destruct H0 as (t' & w' & TR).
      specialize (H3 _ _ TR); cbn in H3.
      next; right.
      split.
      * apply can_step_tau.
        exists t', w'; auto.
      * intros t_ w_ TR_.
        rewrite ktrans_tau in TR_.
        now apply H2.
  Qed.

  Lemma afax_tau: forall (t: itree E X) w φ,
      <( t, w |= AF AX now φ )> -> 
      <( {Tau t}, w |= AF AX (now φ) )>.
  Proof.
    intros.
    Transparent entailsF.
    unfold entailsF in H.
    induction H.
    - destruct H.
      next; left. 
      split.
      + now apply can_step_tau.
      + intros *  TR.
        rewrite ktrans_tau in TR.
        now apply H0 with t'.
    - destruct H0, H1; clear H H1.
      next; right.
      split.
      + now apply can_step_tau.
      + intros * TR.
        rewrite ktrans_tau in TR.
        now apply H2.
  Qed.

  Lemma af_vis: forall (e: E) (k: encode e -> itree E X) (_: encode e) w φ,
      (φ w \/ (not_done w /\ forall (x: encode e), <( {k x}, {Obs e x} |= AF now φ )>)) ->
      <( {Vis e k}, w |= AF now φ )>.        
  Proof.
    intros.
    destruct H as [H | [Hd H]].
    - now next; left.
    - next; right; next; split.
      + now apply can_step_vis.
      + intros t' w' TR'.
        apply ktrans_vis in TR' as (? & ? & -> & ?).
        rewrite H0.
        apply H.
  Qed.

 
End BasicLemmas.

Section AfIndLemma.
  Context {E: Type} {HE: Encode E} {X: Type}
    (φ: itree E X -> World E -> Prop).
  
  (*| [t |= AF φ] is semantic and requires double induction, on [AF] and inside it, in
  [ktrans]. Attempt to simplify to one induction with [AFInd] |*)
  Inductive AFInd: itree E X -> World E -> Prop :=
  | AFIndBase: forall (t: itree E X) (w: World E),
      φ t w ->
      AFInd t w
  | AFIndDoneBase: forall t (x: X),
      observe t = RetF x ->
      φ Itree.stuck (Done x) ->
      AFInd t Pure
  | AFIndFinishBase: forall t (e: E) (v: encode e) (x: X),
      observe t = RetF x ->
      φ Itree.stuck (Finish e v x) ->
      AFInd t (Obs e v)
  | AFIndTau: forall t u w,
      observe t = TauF u ->
      AFInd u w ->
      AFInd t w
  |AFIndVis: forall (t: itree E X) w e k (_: encode e),
      observe t = VisF e k ->
      not_done w ->
      (forall (v: encode e), AFInd (k v) (Obs e v)) ->
      AFInd t w.

  Global Instance proper_equ_afind {HP: Proper (equ eq ==> eq ==> iff) φ}:
    Proper (equ eq ==> eq ==> iff) AFInd.
  Proof.
    unfold Proper, respectful.
    intros; subst; split; intros Hind.
    - generalize dependent y.
      induction Hind; intros.
      + apply AFIndBase; auto.
        now rewrite <- H0.
      + apply AFIndDoneBase with x; auto.
        unfold equ in H1; step in H1; cbn in H1; dependent destruction H1; congruence.
      + apply AFIndFinishBase with x; auto.
        unfold equ in H1; step in H1; cbn in H1; dependent destruction H1; congruence.
      + unfold equ; step in H0; cbn in H0; rewrite H in H0.
        dependent destruction H0.
        apply IHHind in H0.
        apply AFIndTau with t2; congruence.
      + unfold equ; step in H3; cbn in H3; rewrite H in H3.
        dependent destruction H3.
        eapply AFIndVis with e k2; auto.
    - generalize dependent x.
      induction Hind; intros.
      + apply AFIndBase; auto.
        now rewrite H0.
      + apply AFIndDoneBase with x; auto.
        unfold equ in H1; step in H1; cbn in H1; dependent destruction H1; congruence.
      + apply AFIndFinishBase with x; auto.
        unfold equ in H1; step in H1; cbn in H1; dependent destruction H1; congruence.
      + unfold equ; step in H0; cbn in H0; rewrite H in H0.
        dependent destruction H0.
        apply IHHind in H0.
        apply AFIndTau with t1; congruence.
      + unfold equ; step in H3; cbn in H3; rewrite H in H3.
        dependent destruction H3.
        eapply AFIndVis with e k1; auto.
  Qed.      

  Lemma af_ind_stuck_done: forall (x: X),
    AFInd Itree.stuck (Done x) <->
    φ Itree.stuck (Done x).
  Proof.
    split; intros.
    - dependent induction H; auto.
    - now apply AFIndBase.
  Qed.

  Lemma af_ind_stuck_finish: forall (e: E) (v: encode e) (x: X),
    AFInd Itree.stuck (Finish e v x) <->
    φ Itree.stuck (Finish e v x).
  Proof.
    split; intros.
    - dependent induction H; auto.
    - now apply AFIndBase.
  Qed.

  (* This is a super useful lemma, it allows us to do induction on [AFInd]
     instead of two inductions on [cau] and [trans] *)
  Opaque Itree.stuck.
  Lemma af_afind : forall (t: itree E X) (w: World E),
       cau (fun _ _ => True) φ t w -> AFInd t w.
  Proof.
    intros; induction H.
    - now apply AFIndBase.
    - destruct H0, H1; clear H H1.
      destruct H0 as (t' & w' & TR).
      cbn in TR.
      dependent induction TR.
      + observe_equ x.
        eapply AFIndVis with (e:=e) (k:=k); auto.
        intros v'.
        apply H3; cbn.
        rewrite <- x0.
        apply KtransObs; auto.
      + eapply AFIndTau with (u:=t0); auto.
        eapply IHTR with (t':=t'); auto.
        -- intros t_ w_ TR_.
           apply H2; cbn.
           rewrite <- x0.
           now apply ktrans_tau.
        -- intros t_ w_ TR_.
           apply H3; cbn.
           rewrite <- x0.
           now apply ktrans_tau.
      + apply AFIndDoneBase with (x:=x0); auto.
        assert (TR_: [t, Pure] ↦ [Itree.stuck, Done x0]).
        { cbn; rewrite <- x1; apply KtransDone; auto. }
        specialize (H3 _ _ TR_).
        now apply af_ind_stuck_done.
      + apply AFIndFinishBase with (x:=x0); auto.
        assert (TR_: [t, Obs e v] ↦ [Itree.stuck, Finish e v x0]).
        { cbn; rewrite <- x1; apply KtransFinish; auto. }
        specialize (H3 _ _ TR_).
        now apply af_ind_stuck_finish.
  Qed.
  
  (* -> *)
  Lemma afind_af {Hpr: @Productive E HE}
    {HP: Proper (equ eq ==> eq ==> iff) φ}
    {TauInv: forall (t: itree E X) w, φ t w  -> φ (Tau t) w}
    : forall (t: itree E X) (w: World E),
      AFInd t w -> cau (fun _ _ => True) φ t w.
  Proof.
    intros; induction H.
    - now apply MatchA.
    - apply StepA; auto; split.
      + exists Itree.stuck, (Done x).
        Opaque Itree.stuck.
        cbn. rewrite H.
        apply KtransDone; auto.
      + intros t' w' TR.
        ktrans_ind TR.
        * rewrite H in x1; inv x1.
        * rewrite H in x1; inv x1.
        * rewrite H in x2; inv x2.          
          observe_equ x.
          rewrite <- Eqt, H1.          
          now apply MatchA.
    - apply StepA; auto; split.
      + exists Itree.stuck, (Finish e v x).
        Opaque Itree.stuck.
        cbn. rewrite H.
        apply KtransFinish; auto.
      + intros t' w' TR.
        ktrans_ind TR.
        * rewrite H in x1; inv x1.
        * rewrite H in x1; inv x1.
        * rewrite H in x2; inv x2.          
          observe_equ x.
          rewrite <- Eqt, H1.          
          now apply MatchA.
    - observe_equ H.
      rewrite Eqt; clear Eqt.
      destruct IHAFInd.
      + apply MatchA.
        (* TauInv here *)
        now apply TauInv.
      + destruct H2.
        apply StepA; auto.
        split; auto with ctl.
        intros t' w' TR.
        apply H3.
        now rewrite ktrans_tau in TR.
    - observe_equ H.
      rewrite Eqt; clear Eqt.
      apply StepA; auto; split; auto with ctl.
      intros t' w' TR.
      + apply ktrans_vis in TR as (v & ? & -> & ?).
        rewrite H3.
        eapply H2.
  Qed.
End AfIndLemma.

Section AfDoneIndLemma.
  Context {E: Type} {HE: Encode E} {X: Type}
    (φ: X -> World E -> Prop).

  (* t |= AF AX done R *)
  Inductive AFDoneInd: itree E X -> World E -> Prop :=
  | AFDoneDoneBase: forall t (x: X),
      observe t = RetF x ->
      φ x Pure ->
      AFDoneInd t Pure
  | AFDoneFinishBase: forall t (e: E) (v: encode e) (x: X),
      observe t = RetF x ->
      φ x (Obs e v) ->
      AFDoneInd t (Obs e v)
  | AFDoneIndTau: forall t u w,
      observe t = TauF u ->
      AFDoneInd u w ->
      AFDoneInd t w
  |AFDoneIndVis: forall (t: itree E X) w e k (_: encode e),
      observe t = VisF e k ->
      not_done w ->
      (forall (v: encode e), AFDoneInd (k v) (Obs e v)) ->
      AFDoneInd t w.


  Global Instance proper_equ_afdoneind:
    Proper (equ eq ==> eq ==> iff) AFDoneInd.
  Proof.
    unfold Proper, respectful.
    intros; subst; split; intros Hind.
    - generalize dependent y.
      induction Hind; intros.
      + apply AFDoneDoneBase with x; auto.
        rewrite <- H.
        unfold equ in H.
        step in H1; cbn in H1; dependent destruction H1;
          congruence.
      + apply AFDoneFinishBase with x; auto.
        rewrite <- H.
        step in H1; cbn in H1; dependent destruction H1;
          congruence.
      + unfold equ; step in H0; cbn in H0; rewrite H in H0.
        dependent destruction H0.
        apply IHHind in H0.
        apply AFDoneIndTau with t2; congruence.
      + unfold equ; step in H3; cbn in H3; rewrite H in H3.
        dependent destruction H3.
        eapply AFDoneIndVis with e k2; auto.
    - generalize dependent x.
      induction Hind; intros.
      + apply AFDoneDoneBase with x; auto.
        rewrite <- H.
        unfold equ in H.
        step in H1; cbn in H1; dependent destruction H1;
          congruence.
      + apply AFDoneFinishBase with x; auto.
        rewrite <- H.
        step in H1; cbn in H1; dependent destruction H1;
          congruence.
      + unfold equ; step in H0; cbn in H0; rewrite H in H0.
        dependent destruction H0.
        apply IHHind in H0.
        apply AFDoneIndTau with t1; congruence.
      + unfold equ; step in H3; cbn in H3; rewrite H in H3.
        dependent destruction H3.
        eapply AFDoneIndVis with e k1; auto.
  Qed.

  Lemma afdoneind_stuck: forall w,
      ~ (AFDoneInd Itree.stuck w).
  Proof.
    intros * Hcontra.
    dependent induction Hcontra; eauto.
  Qed.

  Lemma afdone_ind: forall (t: itree E X) w,
      <( t, w |= AF AX done φ )> ->
      AFDoneInd t w.
  Proof.
    intros; induction H.
    - next in H.
      destruct H as [(t' & w' & TR) H].
      cbn in TR.
      dependent induction TR.
      + eapply AFDoneIndVis; eauto.
        intros v'.
        assert (TR: ktrans_ (observe t) w (observe (k v')) (Obs e v')).
        { rewrite <- x0; apply ktrans_vis; exists v'; eauto. }
        specialize (H1 _ _ TR).
        rewrite ctl_done in H1.
        inv H1.
      + eapply AFDoneIndTau with (u:=t0); auto.
        eapply IHTR; auto.
        intros t_ w_ TR_.
        apply H; cbn.
        rewrite <- x0.
        now apply ktrans_tau.
      + eapply AFDoneDoneBase with (x:=x0); auto.
        assert (TR: ktrans_ (observe t) Pure (observe Itree.stuck) (Done x0)).
        { rewrite <- x1; econstructor; auto. }
        specialize (H0 _ _ TR).
        rewrite ctl_done in H0.
        now dependent destruction H0.
      + eapply AFDoneFinishBase with (x:=x0); auto.
        assert (TR: ktrans_ (observe t) (Obs e v) (observe Itree.stuck) (Finish e v x0)).
        { rewrite <- x1; econstructor; auto. }
        specialize (H0 _ _ TR).
        rewrite ctl_done in H0.
        now dependent destruction H0.
    -  destruct H0, H1; clear H H1.
       destruct H0 as (t' & w' & TR).
       cbn in TR.
       dependent induction TR.
       + observe_equ x.
         eapply AFDoneIndVis with (e:=e) (k:=k); auto.
         intros v'.
         apply H3; cbn.
         rewrite <- x0.
         apply KtransObs; auto.
      + eapply AFDoneIndTau with (u:=t0); auto.
        eapply (IHTR) with (t':=t'); auto.
        -- intros t_ w_ TR_.
           apply H2; cbn.
           rewrite <- x0.
           now apply ktrans_tau.
        -- intros t_ w_ TR_.
           apply H3; cbn.
           rewrite <- x0.
           now apply ktrans_tau.
      + apply AFDoneDoneBase with (x:=x0); auto.
        assert (TR_: ktrans_ (observe t) Pure (observe Itree.stuck) (Done x0)).
        { rewrite <- x1; apply KtransDone; auto. }
        specialize (H3 _ _ TR_).
        now apply afdoneind_stuck in H3.
      + apply AFDoneFinishBase with (x:=x0); auto.
        assert (TR_: ktrans_ (observe t) (Obs e v) (observe Itree.stuck) (Finish e v x0)).
        { rewrite <- x1; apply KtransFinish; auto. }
        specialize (H3 _ _ TR_).
        now apply afdoneind_stuck in H3.
  Qed.

  Lemma af_ret_inv: forall (x: X) w R,
      <( {Ret x}, w |= AF (AX done R) )> ->
      R x w.
  Proof.
    intros.
    apply af_afind in H.
    dependent induction H.
    - destruct H.
      destruct H as (t' & w' & TR).
      specialize (H0 _ _ TR).
      inv H0; destruct w; cbn in TR; dependent destruction TR; auto.
    - destruct H0.
      apply can_step_not_done in H.
      inv H.
    - destruct H0.
      apply can_step_not_done in H.
      inv H.
  Qed.

End AfDoneIndLemma.

Section CtlAfBind.
  Context {E: Type} {HE: Encode E}.

  Lemma af_stuck{X}: forall φ w,
      φ w <->
      <( {Itree.stuck: itree E X}, w |= AF now φ )>.
  Proof.
    split; intros.
    - next; left; auto.
    - remember Itree.stuck as S. 
      apply af_afind in H.
      Transparent Itree.stuck.
      induction H; subst; auto; cbn in *;
        dependent destruction H; auto.      
  Qed.

  Theorem af_bind_vis{X Y}: forall (t: itree E Y) (k: Y -> itree E X) φ w,
      <( t, w |= AF vis φ )> ->
      <( {x <- t ;; k x}, w |= AF vis φ )>.
  Proof.
    intros * Haf.
    apply af_afind in Haf.
    revert X k.    
    induction Haf; intros; subst. 
    - (* Base *)
      next; left; cbn; apply H.
    - (* Done *)
      inv H0.
    - (* Finish *)
      inv H0.
    - (* Tau *)
      observe_equ H.
      rewrite Eqt, bind_tau.
      apply af_tau; eauto.
    - (* Vis *)
      observe_equ H.
      rewrite Eqt, bind_vis.
      apply af_vis; eauto.
  Qed.

  Theorem af_bind_pure{X Y}: forall (t: itree E Y) (k: Y -> itree E X) w,
      <( t, w |= AF pure )> ->
      <( {x <- t ;; k x}, w |= AF pure )>.
  Proof.
    intros * Haf.
    apply af_afind in Haf.
    revert X k.    
    induction Haf; intros; subst. 
    - (* Base *)
      next; left; now cbn. 
    - (* Done *)
      inv H0.
    - (* Finish *)
      inv H0.
    - (* Tau *)
      observe_equ H.
      rewrite Eqt, bind_tau.
      apply af_tau; eauto.
    - (* Vis *)
      observe_equ H.
      rewrite Eqt, bind_vis.
      apply af_vis; eauto.
  Qed.
  
  Lemma can_step_bind_r{X Y}: forall (t: itree E Y) (k: Y -> itree E X) w R,      
      <( t, w |= AF AX done R )> ->
      (forall y w, R y w -> can_step (k y) w) ->
      can_step (x <- t ;; k x) w.
  Proof.    
    intros.
    apply afdone_ind in H.
    generalize dependent k.
    induction H; intros; observe_equ H; rewrite Eqt.
    - (* Done x *)
      rewrite bind_ret_l.
      now apply H1.
    - (* Finish *)
      rewrite bind_ret_l.
      now apply H1.
    - (* Tau *)
      rewrite bind_tau.
      apply can_step_tau; eauto.
    - (* Vis *)
      rewrite bind_vis.
      apply can_step_vis; auto.
  Qed.
  Hint Resolve can_step_bind_r: ctl.

  Theorem af_bind_r{X Y}: forall (t: itree E Y)
                            (k: Y -> itree E X) w φ R,
      <( t, w |= AF AX done R )> ->
      (forall (y: Y) w, R y w -> not_done w ->
                   <( {k y}, w |= AF now φ )>) ->
      <( {x <- t ;; k x}, w |= AF now φ )>.
  Proof.
    intros.
    apply afdone_ind in H.
    revert H0.
    generalize dependent φ.
    generalize dependent k.
    induction H; intros; observe_equ H; rewrite Eqt.
    - (* Done *)
      rewrite bind_ret_l; eauto with ctl.
    - (* Finish *)
      rewrite bind_ret_l; eauto with ctl.
    - (* Tau *)
      rewrite bind_tau.
      apply af_tau; eauto with ctl.
    - (* Vis *)
      rewrite bind_vis.
      apply af_vis; eauto with ctl.
  Qed.

End CtlAfBind.

Section CtlAfIter.
  Context {E: Type} {HE: Encode E}.

  (* Total correctness lemma for [iter] *)
  (* [Ri: I -> World E -> Prop] loop invariant (left).
     [Rr: X -> World E -> Prop] loop postcondition (right).
     [Rv: (I * World E) -> (I * World E) -> Prop)] loop variant (left). *)
  Lemma af_iter{X I} Ri Rr (Rv: relation (I * World E)) (i: I) w (k: I -> itree E (I + X)):
      (forall (i: I) w, Ri i w ->
                   <( {k i}, w |= AF AX done {fun (x: I + X) w' =>
                                             match x with
                                             | inl i' => Ri i' w' /\ Rv (i', w') (i, w)
                                             | inr r' => Rr r' w'
                                             end})>) ->
      well_founded Rv ->
      Ri i w ->
      <( {Itree.iter k i}, w |= AF done Rr )>.
  Proof.      
    intros H WfR Hi.
    generalize dependent k.
    revert Hi.
    remember (i, w) as P.
    replace i with (fst P) by now subst.
    replace w with (snd P) by now subst.
    clear HeqP i w.
    Opaque entailsF.
    induction P using (well_founded_induction WfR); (* wf_ind *)
      destruct P as (i, w); cbn in *. 
    rename H into HindWf.
    intros.
    rewrite unfold_iter.
    eapply af_bind_r with (R:=fun (x : I + X) (w' : World E) =>
                                match x with
                                | inl i' => Ri i' w' /\ Rv (i', w') (i, w)
                                | inr r' => Rr r' w'
                                end); auto.
    intros [i' | r] w'.
    - intros (Hi' & Hv) Hd.
      apply af_tau.
      remember (i', w') as y.
      replace i' with (fst y) by now subst.
      replace w' with (snd y) by now subst.      
      apply HindWf; inv Heqy; auto.
    - intros Hr Hd.
      next; right; next; split.
      + now apply can_step_ret.
      + intros t_ w_ TR_.
        inv Hd.
        * apply ktrans_pure in TR_ as (-> & ->).
          next; left.
          rewrite ctl_done.
          now constructor.
        * apply ktrans_finish in TR_ as (-> & ->).
          next; left.
          rewrite ctl_done.
          now constructor.          
  Qed.
End CtlAfIter.
