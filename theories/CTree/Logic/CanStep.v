From Coq Require Import
  Basics
  Init.Wf.

From CTree Require Import
  Events.Core
  CTree.Core
  Events.Core
  CTree.Logic.Trans
  CTree.Interp.State
  CTree.Events.Writer
  CTree.Equ
  Logic.Ctl
  Logic.Kripke.

Generalizable All Variables.

Import CTreeNotations CtlNotations.
Local Open Scope ctl_scope.
Local Open Scope ctree_scope.

(*| CTL logic lemmas on c/itrees |*)
Section CanStepCtrees.
  Context {E: Type} {HE: Encode E}.
  Notation encode := (@encode E HE).

  Global Add Parametric Morphism{X}: (can_step (M:=ctree) (X:=X))
         with signature (equ eq ==> eq ==> iff)
           as proper_ctree_can_step.
  Proof.
    intros t w Ht w'. 
    unfold can_step.
    setoid_rewrite Ht.
    reflexivity.
  Qed.

  (*| Br |*)  
  Lemma can_step_br{n X}: forall (k: fin' n -> ctree E X) w,
      can_step (Br n k) w <-> not_done w.
  Proof.
    split; intros.
    - destruct H as (t' & w' & TR).
      eapply ktrans_not_done; eauto.
    - exists (k Fin.F1), w.
      apply ktrans_br; exists Fin.F1; auto.
  Qed.
  Hint Resolve can_step_br: ctl.
  
  (*| Guard |*)  
  Lemma can_step_guard{X}: forall (t: ctree E X) w,
      can_step (Guard t) w <-> can_step t w.
  Proof.
    split; intros.
    - destruct H as (t' & w' & TR).
      rewrite ktrans_guard in TR.
      now (exists t', w').
    - destruct H as (t' & w' & TR).
      apply ktrans_guard in TR.
      now (exists t', w').
  Qed.
  Hint Resolve can_step_guard: ctl.
  
  Lemma can_step_vis{X}: forall (e:E) (k: encode e -> ctree E X) (_: encode e) w,
      can_step (Vis e k) w <-> not_done w.
  Proof.
    split; intros.
    - destruct H as (t' & w' & TR).
      eapply ktrans_not_done; eauto.
    - exists (k X0), (Obs e X0).
      apply ktrans_vis; exists X0; auto.
  Qed.
  Hint Resolve can_step_vis: ctl.

  Lemma can_step_ret{X}: forall w (x: X),
    not_done w ->
    can_step (Ret x) w.
  Proof.
    intros; inv H.
    Opaque Ctree.stuck.
    - exists Ctree.stuck, (Done x); now constructor. 
    - exists Ctree.stuck, (Finish e v x); now constructor.
  Qed.
  Hint Resolve can_step_ret: ctl.

  Lemma can_step_stuck{X}: forall w,
      ~ (can_step (Ctree.stuck: ctree E X) w).
  Proof.
    intros * (t' & w' & TRcontra).
    now apply ktrans_stuck in TRcontra.
  Qed.
  Hint Resolve can_step_stuck: ctl.

  Typeclasses Transparent equ.
  Lemma can_step_bind{X Y}: forall (t: ctree E Y) (k: Y -> ctree E X) w,
      can_step (x <- t ;; k x) w <->        
        (exists t' w', [t, w] ↦ [t', w'] /\ not_done w')
        \/ (exists y w', [t, w] ↦ [Ctree.stuck, w']
                   /\ done_eq y w'
                   /\ can_step (k y) w).
  Proof with eauto with ctl.
    unfold can_step; split.
    - intros (k' & w' & TR).
      apply ktrans_bind_inv in TR
          as [(t' & TR' & Hd & ?) |
               (x & w_ & TRr & ? & TRk)].
      + left; exists t', w'...
      + right; inv H.
        * exists x0, (Done x0); intuition...
        * exists x0, (Finish e v x0); intuition...
    - intros * [(t' & w' & TR & Hd) |
                 (y & w' & TR & Hd & k_ & w_ & TR_)].
      + exists (x <- t' ;; k x), w'.
        apply ktrans_bind_l...
      + exists k_, w_.
        inv Hd.
        * Opaque Ctree.stuck.
          cbn in TR.
          generalize dependent w_.
          generalize dependent k_.
          generalize dependent k.
          dependent induction TR; intros.
          -- observe_equ x1.
             rewrite Eqt, bind_guard.
             apply ktrans_guard.
             apply IHTR with x0...
          -- inv H.
          -- observe_equ x2.
             now rewrite Eqt, bind_ret_l.
        * cbn in TR.
          generalize dependent w_.
          generalize dependent k_.
          generalize dependent k.
          dependent induction TR; intros.
          -- observe_equ x1.
             rewrite Eqt, bind_guard.
             apply ktrans_guard.
             apply IHTR with x0 e v ...
          -- inv H.
          -- observe_equ x2.
             now rewrite Eqt, bind_ret_l.
  Qed.
  Hint Resolve can_step_bind: ctl.

  Lemma can_step_bind_l{X Y}: forall (t t': ctree E Y) (k: Y -> ctree E X) w w',
      [t, w] ↦ [t', w'] ->
      not_done w' ->
      can_step (x <- t ;; k x) w.
  Proof.
    intros.
    eapply can_step_bind.
    left.
    exists t', w'; auto.
  Qed.
  Hint Resolve can_step_bind_l: ctl.

  Typeclasses Opaque equ.
  Lemma can_step_bind_r{X Y}: forall (t: ctree E Y) (k: Y -> ctree E X) w R,      
      <[ t, w |= AF AX done R ]> ->
      (forall y w, R y w -> can_step (k y) w) ->
      can_step (x <- t ;; k x) w.
  Proof with eauto with ctl. 
    intros.
    apply can_step_bind.
    induction H.
    - destruct H as (? & (t' & w' & TR') & ?).
      cdestruct H.
      cbn in *.      
      remember (observe t) as T.
      remember (observe t') as T'.
      clear HeqT t HeqT' t'.
      induction TR'.
      * edestruct IHTR'...
        -- left. setoid_rewrite ktrans_guard...           
        -- right. setoid_rewrite ktrans_guard...
      * left. exists (k0 i), w; split...
      * left.
        exists (k0 v), (Obs e v); split...
      * assert (TR': [Ret x, Pure] ↦ [Ctree.stuck, Done x])
            by now apply ktrans_done.
        destruct (H1 _ _ TR').
        -- apply ktrans_done in TR' as (? & _).
           ddestruction H5.
           right.
           exists x, (Done x); split... 
        -- cbn in TR'; inv TR'.
      * assert (TR': [Ret x, Obs e v] ↦ [Ctree.stuck, Finish e v x])
            by now apply ktrans_finish.
        destruct (H1 _ _ TR').
        -- apply ktrans_finish in TR' as (? & _).
           dependent destruction H5.
        -- apply ktrans_finish in TR' as (? & _).
           dependent destruction H5.
           right. exists x, (Finish e v x); split... 
    - destruct H as (Hp & Hs & H), H1 as (_ & _ & H1).
      cdestruct Hp. 
      destruct Hs as (t' & w' & TR').
      cbn in *.
      remember (observe t) as T.
      remember (observe t') as T'.
      clear HeqT t HeqT' t'.
      induction TR'.
      * edestruct IHTR'...
        -- setoid_rewrite ktrans_guard.
           left.
           destruct H4 as (? & ? & ? & ?).
           exists x, x0; split...
        -- right.
           destruct H4 as (? & ? & ? & ? & ?).
           exists x, x0; split... 
      * left. exists (k0 i), w...
      * left. exists (k0 v), (Obs e v)... 
      * assert (TR': [Ret x, Pure] ↦ [Ctree.stuck, Done x])
          by now apply ktrans_done.
        destruct (H _ _ TR'); apply ktrans_done in TR' as (-> & _);
          destruct H5 as (Hp & Hs & H5);
          cdestruct Hp; inv H7.
      * assert (TR': [Ret x, Obs e v] ↦ [Ctree.stuck, Finish e v x])
          by now apply ktrans_finish.
        destruct (H _ _ TR'); apply ktrans_finish in TR' as (-> & _);
          destruct H5 as (Hp & Hs & H5);
           cdestruct Hp; inv H7.
  Qed.
  Hint Resolve can_step_bind_r: ctl.

  Lemma can_step_iter{I X}: forall (k: I -> ctree E (I+X))
                              (i: I) t' w w',
      [k i, w] ↦ [t', w'] ->
      not_done w' ->
      can_step (Ctree.iter k i) w.
  Proof.
    intros k i t' w w' TR Hd.
    rewrite unfold_iter.
    apply can_step_bind_l with t' w'; auto.   
  Qed.
  
End CanStepCtrees.

(*| CTL logic lemmas on interpretations of c/itrees |*)
Section CanStepInterp.
  Context {E F S: Type} {HE: Encode E} {HF: Encode F} (h: E ~> stateT S (ctree F)) (s: S).

  Lemma can_step_state_bind_l{X Y}: forall (k: X -> ctree E Y) (s: S) (t: ctree E X) t' w w',
      [interp_state h t s, w] ↦ [t', w'] ->
      not_done w' ->
      can_step (interp_state h (x <- t ;; k x) s) w.
  Proof.
    intros k i t t' w w' TR Hd. 
    rewrite interp_state_bind.
    apply can_step_bind_l with t' w'; auto.   
  Qed.

  Lemma can_step_state_bind_r{X Y}: forall (k: X -> ctree E Y) (s s': S) (t: ctree E X) x w w',
      <[ {interp_state h t s}, w |= AF AX done= {(x,s')} w' ]> ->
      can_step (interp_state h (k x) s') w' ->
      can_step (interp_state h (x <- t ;; k x) s) w.
  Proof.
    intros.
    rewrite interp_state_bind.
    apply can_step_bind_r with (R:= fun p w => (x, s') = p /\ w' = w); auto.
    intros.
    destruct H1, y; subst.
    inv H1; auto.
  Qed.
  
  Lemma can_step_state_iter{I X}: forall (k: I -> ctree E (I+X)) (i: I) t' w w',
      [interp_state h (k i) s, w] ↦ [t', w'] ->
      not_done w' ->
      can_step (interp_state h (Ctree.iter k i) s) w.
  Proof.
    intros k i t' w w' TR Hd.
    rewrite interp_state_unfold_iter.
    apply can_step_bind_l with t' w'; auto.   
  Qed.
End CanStepInterp.
