From ExtLib Require Export
  Structures.MonadState
  Data.Monads.StateMonad
  Structures.Monad.

From CTree Require Import
  Classes
  CTree.Core
  CTree.Interp.Core
  Events.Core
  CTree.Events.Writer
  CTree.Logic.Trans
  CTree.Events.State
  CTree.Equ.

From Coinduction Require Import
  coinduction.
From Coq Require Import Morphisms.

Import CTreeNotations.
Local Open Scope ctree_scope.

Set Implicit Arguments.
Generalizable All Variables.

(*| Observe 1-to-1 interpretation event-to-state -- [state S] to [stateT S (ctree void)] |*)
Global Instance h_state_stateT {E Σ} (h:E ~> state Σ): E ~> stateT Σ (ctree void) := {
    handler e :=
      mkStateT (fun s => Ret (runState (h.(handler) e) s))
  }.

(*| Intrument by an evaluation [E ~> stateT Σ ctree] and observation function [obs] |*)
Global Instance h_stateT_writerA {E W Σ} (h:E ~> stateT Σ (ctree void))
  (obs: forall (e: E), encode e -> Σ -> W):
  E ~> stateT Σ (ctree (writerE W)) := {
    handler e :=
      mkStateT (fun s =>
                  '(x, σ) <- resumCtree (runStateT (h.(handler) e) s) ;;
                  Ctree.trigger (Log (obs e x σ)) ;;
                  Ret (x, σ))
  }.

(*| Observe states. The [stateT S (ctree void)] to [stateT S (ctree (writerE S))] |*)
Global Instance h_stateT_writerΣ {E Σ} (h:E ~> stateT Σ (ctree void)):
  E ~> stateT Σ (ctree (writerE Σ)) := {
    handler := @handler _ _ (h_stateT_writerA h (fun _ _ s => s))
  }.

(*| Lemmas about state |*)
Definition interp_state {E W} `{EF: Encode F} (h : E ~> stateT W (ctree F))
  {X} (t: ctree E X) (w: W) : ctree F (X*W) := runStateT (interp h t) w.

(*| Unfolding of [interp_state] given state [s] *)
Notation interp_state_ h t s :=
  (match observe t with
   | RetF r => Ret (r, s)
   | VisF e k => (runStateT (h.(handler) e) s) >>=
                  (fun '(x, s') => guard (interp_state h (k x) s'))
   | BrF b n k => Br b n (fun xs => guard (interp_state h (k xs) s))
   end)%function.

Lemma unfold_interp_state `{Encode F} `(h: E ~> stateT W (ctree F))
  {X} (t: ctree E X) (w : W) :
  interp_state h t w ≅ interp_state_ h t w.
Proof.
  unfold interp_state.  
  unfold interp, iter, MonadIter_stateT, MonadIter_ctree.
  setoid_rewrite unfold_iter at 1.
  cbn.
  rewrite bind_bind.
  desobs t; cbn.
  - now repeat (cbn; rewrite ?bind_ret_l).
  - unfold mbr, MonadBr_ctree.
    rewrite ?bind_bind, ?bind_branch.
    apply br_equ; intros.
    now cbn; rewrite ?bind_ret_l.
  - rewrite ?bind_bind.
    upto_bind_equ.
    destruct x1 eqn:Hx1.
    rewrite ?bind_ret_l; cbn.
    reflexivity.
Qed.

#[global] Instance equ_interp_state `{Encode F} `(h: E ~> stateT W (ctree F)) {X}:
  Proper (@equ E _ X X eq ==> eq ==> equ eq) (interp_state h).
Proof.
  unfold Proper, respectful.
  coinduction ? IH; intros * EQ1 * <-.
  rewrite !unfold_interp_state.
  step in EQ1; inv EQ1; auto.
  - cbn. upto_bind_equ.
    destruct x1.
    constructor; intros.
    apply IH; auto.
    apply H2.
  - cbn.
    constructor; intros.
    step.
    econstructor; intros FF.
    dependent destruction FF; try inversion FF.
    apply IH; auto.
    apply H2.
Qed.

Lemma interp_state_ret `{Encode F} `(h: E ~> stateT W (ctree F)) {X} (w : W) (r : X) :
  (interp_state h (Ret r) w) ≅ (Ret (r, w)).
Proof.
  rewrite ctree_eta. reflexivity.
Qed.

Lemma interp_state_vis `{Encode F} `(h: E ~> stateT W (ctree F)) {X}  
  (e : E) (k : encode e -> ctree E X) (w : W) :
  interp_state h (Vis e k) w ≅ runStateT (h.(handler) e) w >>=
    (fun '(x, w') => guard (interp_state h (k x) w')).
Proof.
  rewrite unfold_interp_state; reflexivity.
Qed.

Lemma interp_state_trigger `{Encode F} `(h: E ~> stateT W (ctree F))
  (e : E) (w : W) :
  interp_state h (Ctree.trigger e) w ≅ runStateT (h.(handler) (resum e)) w >>= fun x => guard (Ret x).
Proof.
  unfold Ctree.trigger.
  rewrite interp_state_vis.
  upto_bind_equ.
  destruct x1.
  setoid_rewrite interp_state_ret.
  reflexivity.
Qed.  

Lemma interp_state_br `{Encode F} `(h: E ~> stateT W (ctree F)) {X}
  (n : nat) (k : fin' n -> ctree E X) (w : W) b :
  interp_state h (Br b n k) w ≅ Br b n (fun x => guard (interp_state h (k x) w)).
Proof.
  rewrite !unfold_interp_state; reflexivity.
Qed.

Lemma interp_state_ret_inv `{Encode F} `(h: E ~> stateT W (ctree F)) {X}:
  forall s (t : ctree E X) r,
    interp_state h t s ≅ Ret r -> t ≅ Ret (fst r) /\ s = snd r.
Proof.
  intros.
  setoid_rewrite (ctree_eta t) in H0.
  setoid_rewrite (ctree_eta t).
  destruct (observe t) eqn:?.
  - rewrite interp_state_ret in H0. step in H0. inv H0. split; reflexivity.
  - rewrite interp_state_br in H0. step in H0. inv H0.
  - rewrite interp_state_vis in H0. apply ret_equ_bind in H0 as (? & ? & ?).
    destruct x.
    step in H1.
    inv H1.
Qed.

Arguments interp_state: simpl never.
Local Typeclasses Transparent equ.
Lemma interp_state_bind `{Encode F} `(h : E ~> stateT W (ctree F)) {A B}
  (t : ctree E A) (k : A -> ctree E B) (s : W) :
  interp_state h (t >>= k) s ≅ interp_state h t s >>= fun '(x, s) => interp_state h (k x) s.
Proof.
  revert s t.
  coinduction ? IH; intros.
  rewrite (ctree_eta t).
  rewrite unfold_bind, unfold_interp_state.
  destruct (observe t) eqn:Hobs; cbn.
  - rewrite interp_state_ret, bind_ret_l.
    cbn.
    rewrite unfold_interp_state.
    reflexivity.
  - rewrite interp_state_br.
    rewrite bind_br.
    setoid_rewrite bind_guard.
    constructor; intro i.
    step; econstructor; intros.
    apply IH.
  - rewrite interp_state_vis, bind_bind.
    upto_bind_equ; destruct x.
    rewrite bind_guard.
    constructor; intros ?; apply IH.
Qed.

Lemma interp_state_unfold_iter `{Encode F} `(h : E ~> stateT W (ctree F)) {I R}
  (k : I -> ctree E (I + R)) (i: I) (s: W) :
  interp_state h (iter k i) s ≅ interp_state h (k i) s >>= fun '(x, s) =>
      match x with
      | inl l => guard (guard (interp_state h (iter k l) s))
      | inr r => Ret (r, s)
      end.
Proof.
  Opaque interp_state.
  setoid_rewrite unfold_iter.
  rewrite interp_state_bind.
  upto_bind_equ.
  destruct x1 as [[l | r] s'].
  - rewrite interp_state_br.
    reflexivity.
  - rewrite interp_state_ret.
    reflexivity.
Qed.

