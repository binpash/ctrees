From Coq Require Import
  Basics
  Init.Wf.

From CTree Require Import
  Events.Core
  CTree.Core
  CTree.Logic.Trans
  CTree.Equ
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
  Notation equiv_ctl X := (equiv_ctl (X:=X) (M:= ctree E)).

  Global Add Parametric Morphism{X}: (can_step (M:=ctree E) (X:=X))
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
  
  (*| Tau |*)  
  Lemma can_step_tau{X}: forall (t: ctree E X) w,
      can_step (Tau t) w <-> can_step t w.
  Proof.
    split; intros.
    - destruct H as (t' & w' & TR).
      rewrite ktrans_tau in TR.
      now (exists t', w').
    - destruct H as (t' & w' & TR).
      apply ktrans_tau in TR.
      now (exists t', w').
  Qed.
  Hint Resolve can_step_tau: ctl.
  
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
                   /\ return_val Y y w'
                   /\ can_step (k y) w).
  Proof with eauto with ctl.
    unfold can_step; split.
    - intros (k' & w' & TR).
      apply ktrans_bind_inv in TR
          as [(t' & TR' & Hd & ?) | [(y & ? & -> & ?) | (e' & v' & x' & TR & -> & TRk)]].
      + left; exists t', w'...
      + right. 
        exists y, (Done y)...
      + right.
        exists x', (Finish e' v' x')...
    - intros * [(t' & w' & TR & Hd) | (y & w' & TR & Hd & k_ & w_ & TR_)].
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
          -- observe_equ x0.
             rewrite Eqt, bind_tau.
             apply ktrans_tau.
             apply IHTR with y...
          -- inv H.
          -- observe_equ x1.
             now rewrite Eqt, bind_ret_l.
        * cbn in TR.
          generalize dependent w_.
          generalize dependent k_.
          generalize dependent k.
          dependent induction TR; intros.
          -- observe_equ x0.
             rewrite Eqt, bind_tau.
             apply ktrans_tau.
             apply IHTR with y e v ...
          -- inv H.
          -- observe_equ x1.
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
  
  Lemma can_step_bind_r{X Y}: forall (t: ctree E Y) (k: Y -> ctree E X) w R,      
      <( t, w |= AF AX done R )> ->
      (forall y w, R y w -> can_step (k y) w) ->
      can_step (x <- t ;; k x) w.
  Proof.    
    intros.
    apply can_step_bind.
    induction H.
    - destruct H as ((t' & w' & TR') & ?).
      cbn in *.
      remember (observe t) as T.
      remember (observe t') as T'.
      clear HeqT t HeqT' t'.
      induction TR'.
      * edestruct IHTR'.
          -- intros t_ w_ TR_; eauto.
          -- setoid_rewrite ktrans_brD.
             left.
             destruct H1 as (? & ? & ?).
             exists x, x0; split.
             ++ now (exists i).
             ++ now destruct H1.
          -- right.
             destruct H1 as (? & ? & ? & ? & ?).
             exists x, x0; split; auto.             
             apply ktrans_brD.
             now (exists i).
      * left.
        exists (k0 i), w.
        split; auto.
        apply ktrans_brS.
        exists i; auto.
      * left.
        exists (k0 v), (Obs e v); auto with ctl.
      * assert (TR': [Ret x, Pure] ↦ [Ctree.stuck, Done x])
            by now apply ktrans_done.
        destruct (H _ _ TR').
        -- apply ktrans_done in TR' as (? & _).
           dependent destruction H3.
           right.
           exists x, (Done x); split; auto with ctl.
        -- cbn in TR'.
           inv TR'.
      * assert (TR': [Ret x, Obs e v] ↦ [Ctree.stuck, Finish e v x])
            by now apply ktrans_finish.
        destruct (H _ _ TR').
        -- apply ktrans_finish in TR' as (? & _).
           dependent destruction H3.
        -- apply ktrans_finish in TR' as (? & _).
           dependent destruction H3.
           right.
           exists x, (Finish e v x); split; auto with ctl.
    - destruct H1, H2; clear H2.
      destruct H1 as (t' & w' & TR').
      cbn in *.
      remember (observe t) as T.
      remember (observe t') as T'.
      clear HeqT t HeqT' t'.
      induction TR'.
      * edestruct IHTR'.
        -- intros t_ w_ TR_; eauto.
        -- intros t_ w_ TR_; eauto.
        -- setoid_rewrite ktrans_brD.
           left.
           destruct H1 as (? & ? & ?).
           exists x, x0; split.
           ++ now (exists i).
           ++ now destruct H1.
        -- right.
           destruct H1 as (? & ? & ? & ? & ?).
           exists x, x0; split; auto.             
           apply ktrans_brD.
           now (exists i).
      * left.
        exists (k0 i), w.
        split; auto.
        apply ktrans_brS.
        exists i; auto.
      * left.
        exists (k0 v), (Obs e v); auto with ctl.
      * assert (TR': [Ret x, Pure] ↦ [Ctree.stuck, Done x])
          by now apply ktrans_done.
        destruct (H3 _ _ TR').
        -- apply ktrans_done in TR' as (-> & _).
           destruct H2.
           apply can_step_not_done in H2; inv H2.
        -- destruct H5.
           apply ktrans_done in TR' as (-> & ?).
           apply can_step_not_done in H5; inv H5.
      * assert (TR': [Ret x, Obs e v] ↦ [Ctree.stuck, Finish e v x])
          by now apply ktrans_finish.
        destruct (H3 _ _ TR').
        -- apply ktrans_finish in TR' as (-> & _).
           destruct H2.
           apply can_step_not_done in H2; inv H2.
        -- destruct H5.
           apply ktrans_finish in TR' as (-> & ?).
           apply can_step_not_done in H5; inv H5.
  Qed.
  Hint Resolve can_step_bind_r: ctl.
  
End CanStepCtrees.
