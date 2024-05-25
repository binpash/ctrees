Unset Universe Checking.

From Coq Require Import Classes.RelationPairs.

From ExtLib Require Import
     Structures.Functor
     Structures.Monad.

From ITree Require Import
     Events.State
     CategoryOps.
Import Basics.Monads.

From CTree Require Import
     CTree
     Fold
     FoldCTree
     Eq
     Eq.Epsilon
     Eq.IterFacts
     Eq.SSimAlt
     Eq.SBisimAlt
     Misc.Pure.

Import SBisimNotations.
Import MonadNotation.
Open Scope monad_scope.

Set Implicit Arguments.

(* TODO MOVE *)
Arguments fequ : simpl never.

#[global] Instance MonadBr_stateT {S M C} {MM : Monad M} {AM : MonadBr C M}:
  MonadBr C (stateT S M) :=
  fun X c s => f <- mbr _ c;; ret (s,f).

#[global] Instance MonadTrigger_stateT {E S M} {MM : Monad M} {MT: MonadTrigger E M} :
  MonadTrigger E (stateT S M) :=
  fun _ e s => v <- mtrigger e;; ret (s, v).

#[global] Instance MonadStuck_stateT {S M} {MS: MonadStuck M} : MonadStuck (stateT S M) :=
  fun _ _ => @mstuck M _ _.

#[global] Instance MonadStep_ctree {S M} {MM : Monad M} {MS : MonadStep M} : MonadStep (stateT S M) :=
  fun s => _ <- mstep;; ret (s,tt).

Definition fold_state {E C M} S
  {FM : Functor M} {MM : Monad M} {IM : MonadIter M} {MV : MonadStuck M} {MS : MonadStep M}
  (h : E ~> stateT S M) (g : C ~> stateT S M) :
  ctree E C ~> stateT S M :=
  fold mstuck mstep h g.

Definition interp_state {E C M} S
  `{FM : Functor M, MM : Monad M, IM : MonadIter M, BM : MonadBr C M, MV : MonadStuck M, MS : MonadStep M}
  (h : E ~> stateT S M) :
  ctree E C ~> stateT S M := interp h.

Definition refine_state {E C M} S
  `{FM : Functor M, MM : Monad M, IM : MonadIter M, BM : MonadTrigger E M, MV : MonadStuck M, MS : MonadStep M}
  (g : C ~> stateT S M) :
  ctree E C ~> stateT S M := refine g.

#[global] Typeclasses Opaque fold_state interp_state refine_state.

Section State.
  Variable (S : Type).
  Variant stateE : Type -> Type :=
    | Get : stateE S
    | Put : S -> stateE unit.

  Definition get {E C} `{stateE -< E} : ctree E C S := trigger Get.
  Definition put {E C} `{stateE -< E} : S -> ctree E C unit := fun s => trigger (Put s).

  Definition h_state {E C} : stateE ~> stateT S (ctree E C) :=
    fun _ e s =>
      match e with
      | Get => Ret (s, s)
      | Put s' => Ret (s', tt)
      end.

  Definition pure_state {E C} : E ~> stateT S (ctree E C)
    := fun _ e s => Vis e (fun x => Ret (s, x)).

  Definition pure_state_choice {E C} : C ~> stateT S (ctree E C)
    := fun _ c s => br c (fun x => Ret (s, x)).

  Definition run_state {E C}
    : ctree (stateE +' E) C ~> stateT S (ctree E C) :=
    fold_state (case_ h_state pure_state) pure_state_choice.

End State.

Ltac break :=
  match goal with
  | v: _ * _ |- _ => destruct v
  end.

(* Stateful handlers [E ~> stateT S (itree F)] and morphisms
   [E ~> state S] define stateful itree morphisms
   [itree E ~> stateT S (itree F)]. *)
Section State.

  Variable (S : Type).
  Context {E F C D : Type -> Type}
          {R : Type}
          (h : E ~> stateT S (ctree F D))
          (g : C ~> stateT S (ctree F D)).

  (** Unfolding of [fold]. *)
  Notation fold_state_ h g t s :=
    (match observe t with
     | RetF r => Ret (s, r)
     | StuckF => Stuck
     | GuardF t => Guard (fold_state h g t s)
     | StepF t => Step (Guard (fold_state h g t s))
     | VisF e k => bind (h _ e s) (fun xs => Guard (fold_state h g (k (snd xs)) (fst xs)))
     | BrF c k => bind (g _ c s) (fun xs => Guard (fold_state h g (k (snd xs)) (fst xs)))
     end)%function.

  Lemma unfold_fold_state (t : ctree E C R) (s : S) :
    fold_state h g t s ≅ fold_state_ h g t s.
  Proof.
    unfold fold_state, fold, MonadIter_stateT0, iter, MonadIter_ctree, Basics.iter.
    rewrite unfold_iter at 1.
    cbn.
    rewrite bind_bind.
    destruct (observe t); cbn.
    - now repeat (cbn; rewrite ?bind_ret_l).
    - now rewrite bind_stuck.
    - rewrite bind_map, bind_bind.
      setoid_rewrite bind_step.
      step; constructor.
      rewrite ?bind_ret_l.
      auto.
    - now rewrite ?bind_ret_l; cbn.
    - rewrite bind_map. cbn.
      upto_bind_eq; intros [].
      now cbn; rewrite ?bind_ret_l.
    - rewrite bind_map. cbn.
      upto_bind_eq; intros [].
      now cbn; rewrite ?bind_ret_l.
  Qed.

  #[global] Instance equ_fold_state:
    Proper (equ eq ==> eq ==> equ eq)
           (fold_state h g (T := R)).
  Proof.
    unfold Proper, respectful.
    coinduction r IH; intros * EQ1 * <-.
    rewrite !unfold_fold_state.
    step in EQ1; inv EQ1; auto.
    - constructor; auto.
    - constructor; step; constructor; auto.
    - upto_bind_eq; intros [].
      constructor; intros; auto.
    - upto_bind_eq; intros [].
      constructor; auto.
  Qed.

  Lemma fold_state_ret
        (s : S) (r : R) :
    (fold_state h g (Ret r) s) ≅ (Ret (s, r)).
  Proof.
    rewrite ctree_eta. reflexivity.
  Qed.

  Lemma fold_state_stuck (s : S) :
    (fold_state (T := R) h g Stuck s) ≅ Stuck.
  Proof.
    now rewrite ctree_eta.
  Qed.

  Lemma fold_state_guard (t : ctree E C R) (s : S) :
    fold_state h g (Guard t) s ≅ Guard (fold_state h g t s).
  Proof.
    now rewrite unfold_fold_state; cbn.
  Qed.

  Lemma fold_state_step (t : ctree E C R) (s : S) :
    fold_state h g (Step t) s ≅ Step (Guard (fold_state h g t s)).
  Proof.
    now rewrite unfold_fold_state; cbn.
  Qed.

  Lemma fold_state_vis {T : Type}
    (e : E T) (k : T -> ctree E C R) (s : S) :
    fold_state h g (Vis e k) s ≅ h e s >>= fun sx => Guard (fold_state h g (k (snd sx)) (fst sx)).
  Proof.
    rewrite unfold_fold_state; reflexivity.
  Qed.

  Lemma fold_state_br {T: Type} `{C -< D}
    (c : C T) (k : T -> ctree E C R) (s : S) :
    fold_state h g (br c k) s ≅ g c s >>= fun sx => Guard (fold_state h g (k (snd sx)) (fst sx)).
  Proof.
    rewrite !unfold_fold_state; reflexivity.
  Qed.

  Lemma fold_state_trigger (e : E R) (s : S) :
    fold_state h g (CTree.trigger e) s ≅
    h e s >>= fun x => Guard (Ret x).
  Proof.
    unfold CTree.trigger.
    rewrite fold_state_vis; cbn.
    upto_bind_eq; intros [].
    rewrite fold_state_ret; auto.
  Qed.

  Lemma fold_state_trigger_sb (e : E R) (s : S)
    : fold_state h g (CTree.trigger e) s ~ h e s.
  Proof.
    unfold CTree.trigger. rewrite fold_state_vis.
    rewrite <- (bind_ret_r (h e s)) at 2.
    cbn.
    upto_bind_eq; intros [].
    now rewrite sb_guard, fold_state_ret.
  Qed.

  (** Unfolding of [interp]. *)
  Notation interp_state_ h t s :=
    (match observe t with
     | RetF r => Ret (s, r)
     | StuckF => Stuck
     | GuardF t => Guard (interp_state h t s)
     | StepF t => Step (Guard (interp_state h t s))
 	   | VisF e k => bind (h _ e s) (fun xs => Guard (interp_state h (k (snd xs)) (fst xs)))
	   | BrF c k => bind (mbr (M := stateT _ _) _ c s) (fun xs => Guard (interp_state h (k (snd xs)) (fst xs)))
     end)%function.

  Lemma unfold_interp_state `{C-<D} (t : ctree E C R) (s : S) :
    interp_state h t s ≅ interp_state_ h t s.
  Proof.
    unfold interp_state, interp, MonadIter_stateT0, fold, MonadIter_ctree, Basics.iter.
    rewrite unfold_iter at 1.
    cbn.
    rewrite bind_bind.
    destruct (observe t); cbn.
    - now repeat (cbn; rewrite ?bind_ret_l).
    - now rewrite bind_stuck.
    - rewrite bind_map, bind_bind.
      setoid_rewrite bind_step.
      step; constructor.
      rewrite ?bind_ret_l.
      auto.
    - now rewrite ?bind_ret_l; cbn.
    - rewrite bind_map. cbn.
      upto_bind_eq; intros [].
      now cbn; rewrite ?bind_ret_l.
    - rewrite bind_map. cbn.
      upto_bind_eq; intros [].
      now cbn; rewrite ?bind_ret_l.
  Qed.

  Lemma equ_interp_state `{C-<D} {Q}:
    Proper (equ Q ==> eq ==> equ (eq * Q))
           (interp_state (C := C) h (T := R)).
  Proof.
    unfold Proper, respectful.
    coinduction r IH; intros * EQ1 * <-.
    rewrite !unfold_interp_state.
    step in EQ1; inv EQ1.
    - constructor. split; auto.
    - constructor.
    - constructor; auto.
    - constructor; step; constructor; auto.
    - upto_bind_eq; intros [].
      constructor; intros; auto.
    - upto_bind_eq; intros [].
      constructor; auto.
  Qed.

  #[global] Instance equ_eq_interp_state `{C-<D}:
    Proper (equ eq ==> eq ==> equ eq)
           (interp_state (C := C) h (T := R)).
  Proof.
    cbn. intros. subst.
    eapply (equ_leq (eq * eq)%signature).
    { intros [] [] []. now f_equal. }
    now apply equ_interp_state.
  Qed.

  Lemma interp_state_ret `{C-<D}
        (s : S) (r : R) :
    (interp_state (C := C) h (Ret r) s) ≅ (Ret (s, r)).
  Proof.
    rewrite ctree_eta. reflexivity.
  Qed.

  Lemma interp_state_stuck `{C-<D} (s : S) :
    interp_state (C := C) (T := R) h Stuck s ≅ Stuck.
  Proof.
    now rewrite unfold_interp_state; cbn.
  Qed.

  Lemma interp_state_guard `{C -< D}
    (t : ctree E C R) (s : S) :
    interp_state h (Guard t) s ≅
    Guard (interp_state h t s).
  Proof.
    now rewrite unfold_interp_state; cbn.
  Qed.

  Lemma interp_state_step `{C -< D}
    (t : ctree E C R) (s : S) :
    interp_state h (Step t) s ≅
    Step (Guard (interp_state h t s)).
  Proof.
    now rewrite unfold_interp_state; cbn.
  Qed.

  Lemma interp_state_vis `{C-<D} {T : Type}
    (e : E T) (k : T -> ctree E C R) (s : S) :
    interp_state h (Vis e k) s ≅ h e s >>= fun sx => Guard (interp_state h (k (snd sx)) (fst sx)).
  Proof.
    rewrite unfold_interp_state; reflexivity.
  Qed.

  Lemma interp_state_br {T: Type} `{C -< D}
    (c : C T) (k : T -> ctree E C R) (s : S) :
    interp_state h (Br c k) s ≅ branch c >>= fun x => Guard (interp_state h (k x) s).
  Proof.
    rewrite !unfold_interp_state; cbn.
    rewrite bind_bind.
    upto_bind_eq; intros ?.
    now rewrite bind_ret_l.
  Qed.

  Lemma interp_state_trigger `{C -< D} : forall (e : E R) st,
  interp_state h (CTree.trigger e : ctree E C R) st ≅ x <- h e st;; Guard (Ret x).
  Proof.
    intros. rewrite unfold_interp_state. cbn.
    upto_bind. reflexivity. intros [] [] <-.
    now rewrite interp_state_ret.
  Qed.

  Lemma interp_interp_state `{C -< D} : forall (t : ctree E C R) s,
    interp h t s ≅ interp_state h t s.
  Proof.
    reflexivity.
  Qed.

  (** Unfolding of [refine]. *)
  Notation refine_state_ g t s :=
    (match observe t with
     | RetF r => Ret (s, r)
     | StuckF => Stuck
     | GuardF t => Guard (refine_state g t s)
     | StepF t => Step (Guard (refine_state g t s))
 	   | VisF e k => bind (mtrigger e) (fun x => Guard (refine_state g (k x) s))
	   | BrF c k => bind (g _ c s) (fun xs => Guard (refine_state g (k (snd xs)) (fst xs)))
     end)%function.

  Lemma unfold_refine_state `{E-<F} (t : ctree E C R) (s : S) :
    refine_state g t s ≅ refine_state_ g t s.
  Proof.
    unfold refine_state, refine, MonadIter_stateT0, fold, MonadIter_ctree, Basics.iter.
    rewrite unfold_iter at 1.
    cbn.
    rewrite !bind_bind.
    destruct (observe t); cbn.
    - now repeat (cbn; rewrite ?bind_ret_l).
    - now rewrite bind_stuck.
    - rewrite bind_map, bind_bind.
      setoid_rewrite bind_step.
      step; constructor.
      rewrite ?bind_ret_l.
      auto.
    - now rewrite ?bind_ret_l; cbn.
    - rewrite bind_map, bind_bind.
      upto_bind_eq; intros ?.
      now cbn; rewrite ?bind_ret_l.
    - rewrite bind_map. cbn.
      upto_bind_eq; intros [].
      now cbn; rewrite ?bind_ret_l.
  Qed.

  #[global] Instance equ_refine_state `{E-<F}:
    Proper (equ eq ==> eq ==> equ eq)
           (refine_state (E := E) g (T := R)).
  Proof.
    unfold Proper, respectful.
    coinduction r IH; intros * EQ1 * <-.
    rewrite !unfold_refine_state.
    step in EQ1; inv EQ1; auto.
    - constructor; auto.
    - constructor; step; constructor; auto.
    - upto_bind_eq; intros ?.
      constructor; intros; auto.
    - upto_bind_eq; intros ?.
      constructor; auto.
  Qed.

  Lemma refine_state_ret `{E-<F}
        (s : S) (r : R) :
    (refine_state (E := E) g (Ret r) s) ≅ (Ret (s, r)).
  Proof.
    rewrite ctree_eta. reflexivity.
  Qed.

  Lemma refine_state_stuck `{E-<F} (s : S) :
    refine_state (E := E) (T := R) g Stuck s ≅ Stuck.
  Proof.
    rewrite ctree_eta. reflexivity.
  Qed.

  Lemma refine_state_guard `{E -< F}
    (t : ctree E C R) (s : S) :
    refine_state g (Guard t) s ≅
    Guard (refine_state g t s).
  Proof.
    now rewrite unfold_refine_state; cbn.
  Qed.

  Lemma refine_state_step `{E -< F}
    (t : ctree E C R) (s : S) :
    refine_state g (Step t) s ≅
    Step (Guard (refine_state g t s)).
  Proof.
    now rewrite unfold_refine_state; cbn.
  Qed.

  Lemma refine_state_vis `{E-<F} {T : Type}
    (e : E T) (k : T -> ctree E C R) (s : S) :
    refine_state g (Vis e k) s ≅
      trigger e >>= fun x => Guard (refine_state g (k x) s).
  Proof.
    rewrite unfold_refine_state; reflexivity.
  Qed.

  Lemma refine_state_br {T: Type} `{E -< F}
    (c : C T) (k : T -> ctree E C R) (s : S) :
    refine_state g (Br c k) s ≅
    g c s >>= fun xs => Guard (refine_state g (k (snd xs)) (fst xs)).
  Proof.
    rewrite !unfold_refine_state; cbn.
    now upto_bind_eq.
  Qed.

End State.

#[global] Instance epsilon_det_interp_state {E F B C X St}
  `{HasB: B -< C} (h : E ~> stateT St (ctree F C)) :
  Proper (@epsilon_det E B X ==> eq ==> epsilon_det)
         (interp_state h (T := X)).
Proof.
  cbn. intros. subst.
  induction H.
  - now subs.
  - subs. rewrite interp_state_guard.
    eapply epsilon_det_guard; [| reflexivity].
    assumption.
Qed.

Section FoldBind.
  Variable (S : Type).
  Context {E F C D : Type -> Type}.

  Lemma fold_state_bind
    (h : E ~> stateT S (ctree F D))
    (g : C ~> stateT S (ctree F D))
    {A B}
    (t : ctree E C A) (k : A -> ctree E C B)
    (s : S) :
    fold_state h g (t >>= k) s
      ≅ fold_state h g t s >>= fun st => fold_state h g (k (snd st)) (fst st).
  Proof.
    revert s t.
    coinduction r IH; intros.
    rewrite (ctree_eta t).
    cbn.
    rewrite unfold_bind.
    rewrite unfold_fold_state.
    destruct (observe t) eqn:Hobs; cbn.
    - rewrite fold_state_ret. rewrite bind_ret_l. cbn.
      rewrite unfold_fold_state. reflexivity.
    - now rewrite fold_state_stuck, bind_stuck.
    - rewrite fold_state_step, bind_step, bind_guard.
      constructor; step; constructor; apply IH.
    - rewrite fold_state_guard, bind_guard.
      constructor; apply IH.
    - rewrite fold_state_vis.
      cbn.
      rewrite bind_bind. cbn.
      upto_bind_eq; intros [].
      rewrite bind_guard.
      constructor; apply IH.
    - rewrite unfold_fold_state.
      cbn.
      rewrite bind_bind.
      upto_bind_eq; intros [].
      rewrite bind_guard.
      constructor; apply IH.
  Qed.

  Lemma interp_state_bind `{C -< D}
    (h : E ~> stateT S (ctree F D))
    {A B}
    (t : ctree E C A) (k : A -> ctree E C B)
    (s : S) :
    interp_state h (CTree.bind t k) s ≅ CTree.bind (interp_state h t s) (fun xs => interp_state h (k (snd xs)) (fst xs)).
  Proof.
    eapply fold_state_bind.
  Qed.

  Lemma refine_state_bind `{E -< F}
    (g : C ~> stateT S (ctree F D))
    {A B}
    (t : ctree E C A) (k : A -> ctree E C B)
    (s : S) :
    refine_state g (CTree.bind t k) s ≅ CTree.bind (refine_state g t s) (fun xs => refine_state g (k (snd xs)) (fst xs)).
  Proof.
    eapply fold_state_bind.
  Qed.
End FoldBind.

Section InterpState.

Context {E F B C : Type -> Type} {X St : Type} `{HasB: B -< C}
  (h : E ~> stateT St (ctree F C)).

Lemma epsilon_interp_state : forall (t t' : ctree E B X) s,
    epsilon t t' ->
    epsilon (interp_state h t s) (interp_state h t' s).
Proof.
  intros; red in H.
  rewrite (ctree_eta t), (ctree_eta t').
  genobs t ot. genobs t' ot'. clear t Heqot t' Heqot'.
  induction H.
  - constructor. rewrite H. reflexivity.
  - rewrite unfold_interp_state. cbn.
    rewrite bind_bind.
    setoid_rewrite bind_br.
    apply epsilon_br with (x := x).
    rewrite !bind_ret_l.
    cbn.
    apply epsilon_guard.
    apply IHepsilon_.
  - rewrite unfold_interp_state; cbn.
    apply epsilon_guard.
    apply IHepsilon_.
Qed.

Lemma interp_state_ret_inv :
  forall s (t : ctree E C X) r,
    interp_state h t s ≅ Ret r -> t ≅ Ret (snd r) /\ s = fst r.
Proof.
  intros * EQ. setoid_rewrite (ctree_eta t) in EQ. setoid_rewrite (ctree_eta t).
  destruct (observe t) eqn:?.
  - rewrite interp_state_ret in EQ; inv_equ; auto.
  - rewrite interp_state_stuck in EQ; inv_equ.
  - rewrite interp_state_step in EQ; inv_equ.
  - rewrite interp_state_guard in EQ; inv_equ.
  - rewrite interp_state_vis in EQ. apply ret_equ_bind in EQ as (? & ? & ?). inv_equ.
  - rewrite interp_state_br in EQ; inv_equ.
Qed.

End InterpState.

Theorem ssim_interp_state_h {E F1 F2 C D1 D2 X St St'}
  `{HC1 : C -< D1} `{HC2 : C -< D2}
  (Ldest : rel (@label F1) (@label F2)) (Rs : rel St St') :
  forall (h : E ~> stateT St (ctree F1 D1)) (h' : E ~> Monads.stateT St' (ctree F2 D2)),
  (Ldest τ τ /\
    forall (x : X) (st : St) (st' : St'),
    Rs st st' ->
    Ldest (val (st, x)) (val (st', x))) ->
  (forall {Z} (e : E Z) st st',
    Rs st st' ->
    h _ e st (≲update_val_rel Ldest (fun '(s, z) '(s', z') => Rs s s' /\ @eq Z z z')) h' _ e st') ->
  forall (t : ctree E C X) st0 st'0,
  Rs st0 st'0 ->
  interp_state h t st0 (≲Ldest) interp_state h' t st'0.
Proof.
  intros * HL Hh * ST *.
  unfold interp_state, interp, fold, Basics.iter, MonadIter_stateT0, Basics.iter, MonadIter_ctree.
  eapply ssim_iter with
    (Ra := fun '(st, t) '(st', t') => Rs st st' /\ t ≅ t')
    (Rb := fun b b' => Ldest (val b) (val b')).
  2, 4: auto. 1: red; reflexivity.
  clear st0 st'0 ST t.
  cbn. intros [st t] [st' t'] [ST EQ]. cbn.
  setoid_rewrite ctree_eta in EQ.
  destruct (observe t) eqn:?, (observe t') eqn:?; inv_equ.
  - rewrite !bind_ret_l. apply ssim_ret. constructor. cbn. now apply HL.
  - rewrite bind_stuck; apply Stuck_ssim.
  - rewrite ?map_bind, ?bind_bind; setoid_rewrite bind_step.
    apply step_ssim_step.
    + repeat (rewrite ?bind_ret_l; rewrite ?map_ret).
      cbn. apply ssim_ret. constructor; cbn; split; auto.
    + constructor; easy.
  - rewrite ?bind_ret_l; cbn.
    apply ssim_ret; constructor; cbn; auto.
  - rewrite !bind_map.
    eapply ssim_clo_bind_gen with (R0 := fun '(st, t) '(st', t') => Rs st st' /\ t = t').
    + red. reflexivity.
    + eapply weq_ssim. apply update_val_rel_update_val_rel. now apply Hh.
    + cbn. intros [] [] [? <-]. apply ssim_ret. constructor; cbn; auto.
  - rewrite !bind_map, !bind_bind. setoid_rewrite bind_branch.
    cbn.
    apply ssim_br_id; intros ?; rewrite ?bind_ret_l.
    apply ssim_ret; constructor; cbn; auto.
Qed.

Definition lift_handler {E F B} (h : E ~> ctree F B) : E ~> Monads.stateT unit (ctree F B) :=
  fun _ e s => CTree.map (fun x => (tt, x)) (h _ e).

Lemma is_simple_lift_handler {E F B} (h : E ~> ctree F B) :
  (forall Y (e : E Y), is_simple (h _ e)) ->
  forall Y (e : E Y) st, is_simple (lift_handler h _ e st).
Proof.
  intros.
  specialize (H Y e). red. destruct H; [left | right]; intros.
  - unfold lift_handler, CTree.map in H0.
    apply trans_bind_inv in H0 as ?. destruct H1 as [(? & ? & ? & ?) | (? & ? & ?)].
    + subs. now apply H in H2.
    + inv_trans. now subst.
  - unfold lift_handler, CTree.map in H0.
    apply trans_bind_inv in H0 as ?. destruct H1 as [(? & ? & ? & ?) | (? & ? & ?)].
    + apply H in H2 as []. exists (tt, x0). subs.
      eapply epsilon_det_bind with (k := fun x => Ret (tt, x)) in H2.
      rewrite bind_ret_l in H2. apply H2.
    + apply H in H1 as [].
      inversion H1; inv_equ.
Qed.

(* Results on interp_state can be transported to interp using interp_lift_handler. *)

Lemma interp_lift_handler {E F B C X} `{HasB: B -< C}
  (h : E ~> ctree F C) (t : ctree E B X) :
  interp h t ≅ CTree.map (fun '(st, x) => x) (interp_state (lift_handler h) t tt).
Proof.
  revert t. coinduction R CH. intros.
  pose proof @map_equ.
  rewrite (ctree_eta t). destruct (observe t) eqn:?.
  - rewrite interp_ret, interp_state_ret. rewrite map_ret. reflexivity.
  - rewrite interp_stuck.
    rewrite interp_state_stuck.
    now rewrite map_stuck.
  - rewrite interp_step, interp_state_step, map_step, map_guard.
    constructor; step; constructor; auto.
  - rewrite interp_guard, interp_state_guard, ?map_guard.
    constructor; auto.
  - rewrite interp_vis, interp_state_vis.
    cbn. unfold lift_handler. rewrite map_bind, bind_map.
    upto_bind_eq; intros ?.
    rewrite map_guard.
    constructor. apply CH.
  - rewrite interp_br, interp_state_br.
    cbn. rewrite bind_branch, map_bind, bind_branch.
    constructor. intros.
    rewrite map_guard.
    step. constructor.
    apply CH.
Qed.

Theorem ssim_interp_h {E F1 F2 C D1 D2 X}
  `{HC1 : C -< D1} `{HC2 : C -< D2}
  (Ldest : rel (@label F1) (@label F2)) :
  forall (h : E ~> ctree F1 D1) (h' : E ~> ctree F2 D2),
  (Ldest τ τ /\ forall (x : X), Ldest (val x) (val x)) ->
  (forall {Z} (e : E Z), h _ e (≲update_val_rel Ldest (@eq Z)) h' _ e) ->
  forall (t : ctree E C X),
  interp h t (≲Ldest) interp h' t.
Proof.
  intros.
  rewrite !interp_lift_handler.
  unfold CTree.map. eapply ssim_clo_bind with (R0 := eq).
  2: { intros [] ? <-. apply ssim_ret. apply H. }
  eapply ssim_interp_state_h.
  3: reflexivity.
  - split. { constructor; etrans. apply H. }
    intros ??? <-. now constructor.
  - intros ???? <-.
    eapply weq_ssim. apply update_val_rel_update_val_rel.
    unfold lift_handler, CTree.map.
    eapply ssim_clo_bind. {
      eapply weq_ssim. apply update_val_rel_update_val_rel.
      apply H0.
    }
    intros ?? <-. apply ssim_ret. now constructor.
Qed.

Lemma trans_val_interp_state {E F B C X St}
  `{HasB: B -< C}
  (h : E ~> stateT St (ctree F C)) :
  forall (t u : ctree E B X) (v : X) st,
  trans (val v) t u ->
  trans (val (st, v)) (interp_state h t st) Stuck.
Proof.
  cbn. intros.
  apply trans_val_epsilon in H as []. subs.
  eapply epsilon_interp_state in H.
  eapply epsilon_trans; [apply H |].
  rewrite interp_state_ret. etrans.
Qed.

Lemma trans_τ_interp_state {E F B C X St}
  `{HasB: B -< C}
  (h : E ~> stateT St (ctree F C)) :
  forall (t u : ctree E B X) st,
  trans τ t u ->
  trans τ (interp_state h t st) (Guard (interp_state h u st)).
Proof.
  cbn. intros.
  apply trans_τ_epsilon in H as (? & ? & ?); subst.
  eapply epsilon_interp_state in H.
  eapply epsilon_trans; [apply H |].
  rewrite interp_state_step.
  rewrite H0. etrans.
Qed.

Lemma trans_obs_interp_state_step {E F B C X Y St}
  `{HasB: B -< C}
  (h : E ~> stateT St (ctree F C)) :
  forall (t u : ctree E B X) st st' u' (e : E Y) x l,
  trans (obs e x) t u ->
  trans l (h _ e st) u' ->
  ~ is_val l ->
  epsilon_det u' (Ret (st', x)) ->
  trans l (interp_state h t st) (u';; Guard (interp_state h u st')).
Proof.
  cbn. intros.
  apply trans_obs_epsilon in H as (? & ? & ?).
  setoid_rewrite H3. clear H3.
  eapply epsilon_interp_state with (h := h) in H.
  rewrite interp_state_vis in H.
  eapply epsilon_trans. apply H.
  epose proof (epsilon_det_bind_ret_l_equ u' (fun sx => Guard (interp_state h (x0 (snd sx)) (fst sx))) (st', x) H2).
  rewrite <- H3; auto.
  apply trans_bind_l; auto.
Qed.

Lemma trans_obs_interp_state_pure {E F B C X Y St}
  `{HasB: B -< C}
  (h : E ~> stateT St (ctree F C)) :
  forall (t u : ctree E B X) st st' (e : E Y) x,
  trans (obs e x) t u ->
  trans (val (st', x)) (h _ e st) Stuck ->
  epsilon (interp_state h t st) (Guard (interp_state h u st')).
Proof.
  cbn. intros t u st st' e x TR TRh.
  apply trans_obs_epsilon in TR as (k & EPS & ?). subs.
  eapply epsilon_interp_state with (h := h) in EPS.
  rewrite interp_state_vis in EPS.
  apply trans_val_epsilon in TRh as [EPSh _].
  eapply epsilon_bind_ret in EPSh.
  apply (epsilon_transitive _ _ _ EPS EPSh).
Qed.

(* Direct proof that interp_state preserves ssim. *)

(* Import SSim'Notations. *)


  Lemma ss_step_l_inv {E C X F D Y L R} :
    forall (t : ctree E C X) (u : ctree F D Y),
    ss L R (Step t) u ->
    exists l' u', trans l' u u' /\ R t u' /\ L τ l'.
  Proof.
    intros. apply H; etrans.
  Qed.

  Lemma ssim_step_l_inv {E C X F D Y L} :
    forall (t : ctree E C X) (u : ctree F D Y),
    ssim L (Step t) u ->
    exists l' u', trans l' u u' /\ ssim L t u' /\ L τ l'.
  Proof.
    intros. step in H.
    now apply ss_step_l_inv in H.
  Qed.

#[global] Instance interp_state_ssim {E F B C X St} {R : relation X}
  `{HasB: B -< C} :
  forall (h : E ~> stateT St (ctree F C)) (Hh : forall X e st, is_simple (h X e st)),
  Proper (ssim (lift_val_rel R) ==> eq ==> ssim (lift_val_rel (@eq St * R)%signature))
    (interp_state (C := B) h (T := X)).
Proof.
  intros h Hh t u SIM st st' <-.
  rewrite ssim_ssim'.
  revert t u st SIM.
  red. coinduction CR CH. intros.
  rewrite unfold_interp_state.
  setoid_rewrite ctree_eta at 1 in SIM. destruct (observe t) eqn:?.
  - (* Ret *)
    apply ssim_ret_l_inv in SIM as (? & ? & ? & ?).
    apply update_val_rel_val_l in H0 as ?. destruct H1 as (? & -> & VAL).
    eapply trans_val_interp_state in H.
    apply ss_sst'.
    eapply step_ss_ret_l_gen; eauto.
    apply ss'_stuck.
    typeclasses eauto.
    left. split; auto.
  - apply ss'_stuck.
  - apply step_ss'_step_l.
    apply ssim_step_l_inv in SIM as (? & u' & TR & SIM & VAL).
    apply update_val_rel_nonval_l in VAL as (_ & <-); etrans.
    exists τ, (Guard (interp_state h u' st)).
    ssplit.
    * now apply trans_τ_interp_state.
    * step. apply step_ss'_guard. apply CH. apply SIM.
    * constructor; etrans.
  - apply step_ss'_guard_l.
    apply ssim_guard_l_inv in SIM.
    apply CH; auto.
  - (* Vis *)
    specialize (Hh _ e st). destruct Hh as [Hh | Hh].
    + (* pure handler *)
      assert (equ eq (interp_state h u st) (Ret tt;; interp_state h u st)) by
        now setoid_rewrite bind_ret_l. rewrite H. clear H.
      eapply SSimAlt.bind_chain_gen with (R0 := (fun sx _ => trans (val sx) (h X0 e st) Stuck)).
      apply update_val_rel_correct.
      {
        step. cbn. fold_ssim. intros l t' TR.
        apply Hh in TR as VAL.
        eapply wf_val_is_val_inv in VAL; etrans. destruct VAL as [? ->].
        apply trans_val_inv in TR as ?. exists (val tt), Stuck. subs.
        split; etrans. split.
        - apply is_stuck_ssim. apply Stuck_is_stuck.
        - now apply update_Val.
      }
      intros [st' x] _ TRh.
      simple eapply ssim_vis_l_inv in SIM.
      destruct SIM as (l & u' & TR & SIM & VAL).
      apply update_val_rel_nonval_l in VAL; etrans. destruct VAL as (_ & <-).
      eapply epsilon_ctx_r_sst'; cbn; red.
      eexists. split.
      * eapply trans_obs_interp_state_pure; eauto.
      * unshelve eapply step_ss'_guard.
        apply equ_clos_sst'_ctx.
        apply CH. apply SIM.
    + (* handler that takes exactly one transition *)
      apply ss_sst'.
      Arguments ss' : simpl never.
      cbn. intros l t' TR.
      apply trans_bind_inv in TR as [(VAL & th & TRh & EQ) | (x & TRh & TR)].
      2: {
        apply Hh in TRh as []. inversion H; subst; inv_equ.
      }
      apply Hh in TRh as ?. destruct H as [[st' x] EPS].
      simple eapply ssim_vis_l_inv in SIM.
      destruct SIM as (l' & u' & TR & SIM & VAL').
      apply update_val_rel_nonval_l in VAL'; etrans. destruct VAL' as (? & <-).
      exists l, (th;; Guard (interp_state h u' st')). subs.
      split; [| split; auto].
      * cbn. apply (trans_obs_interp_state_step h st TR); eauto.
      * cbn. rewrite epsilon_det_bind_ret_l_equ with (x := (st', x)); auto.
        cbn.
        eapply SSimAlt.bind_chain_gen with (R0 := eq).
        apply update_val_rel_correct.
        eapply Lequiv_ssim. unfold lift_val_rel.
          rewrite update_val_rel_update_val_rel. rewrite update_val_rel_eq. reflexivity. reflexivity.
          intros [] ? <-.
          cbn.
          unshelve eapply step_ss'_guard.
          apply equ_clos_sst'_ctx.
          eauto.
      * constructor; auto.
  - (* Br *)
    unfold MonadBr_stateT, mbr, MonadBr_ctree. cbn. rewrite bind_bind, bind_branch.
    unshelve eapply step_ss'_br_l.
    apply equ_clos_sst'_ctx.
    intros.
    eapply ssim_br_l_inv in SIM.
    step. rewrite bind_ret_l. apply step_ss'_guard_l.
    apply CH. apply SIM.
Qed.

#[global] Instance interp_state_ssim_eq {E F B C X St}
  `{HasB: B -< C} :
  forall (h : E ~> stateT St (ctree F C)) (Hh : forall X e st, is_simple (h X e st)),
  Proper (ssim eq ==> eq ==> ssim eq) (interp_state (C := B) h (T := X)).
Proof.
  intros h Hh t u SIM st st' <-.
  eapply Lequiv_ssim with (x := lift_val_rel (@eq St * @eq X)%signature).
  eassert (weq (@eq St * @eq X)%signature eq).
  { cbn. unfold RelCompFun. intros [] []; cbn. split; [intros [] | intros [=]]; subst; auto. }
  unfold lift_val_rel. rewrite H; auto. apply update_val_rel_eq.
  eapply interp_state_ssim; auto.
  eapply Lequiv_ssim. symmetry. apply update_val_rel_eq. apply SIM.
Qed.

(* The proof that interp preserves ssim reuses the interp_state proof. *)

#[global] Instance interp_ssim_eq {E F B C X} `{HasB: B -< C} :
  forall (h : E ~> ctree F C) (Hh : forall X e, is_simple (h X e)),
  Proper (ssim eq ==> ssim eq) (interp (B := B) h (T := X)).
Proof.
  intros. cbn. intros.
  rewrite !interp_lift_handler.
  unfold CTree.map. apply ssim_clo_bind_eq.
  refine (interp_state_ssim_eq _ _ _ _); auto.
  reflexivity.
Qed.

(* Direct proof that interp_state preserves sbisim. *)

Arguments sb' : simpl never.

Lemma interp_state_sbisim_aux {E F B C X St}
  {R : relation X} {SYM : Symmetric R} `{HasB: B -< C} :
  forall (h : E ~> stateT St (ctree F C)) (Hh : forall X e st, is_simple (h X e st))
  (t u : ctree E B X) st,
  ss (lift_val_rel R) (sbisim (lift_val_rel R)) t u ->
  gfp (sb' (lift_val_rel (@eq St * R)%signature)) true
    (interp_state h t st) (interp_state h u st).
Proof.
  intros h Hh. coinduction CR CH. intros t u st SIM.
  rewrite unfold_interp_state.
  setoid_rewrite ctree_eta at 1 in SIM. destruct (observe t) eqn:?.
  - (* Ret *)
    apply ss_ret_l_inv in SIM as (? & ? & ? & ? & ?).
    apply update_val_rel_val_l in H1 as ?. destruct H2 as (? & -> & VAL).
    eapply trans_val_interp_state in H.
    apply sb'_true_ss'. eapply step_ss'_ret_l; eauto.
    intros. step. split; intros; apply ss'_stuck.
    constructor. auto.
  - apply sb'_true_stuck.
  - apply step_sb'_true_step_l.
    simple eapply ss_step_l_inv in SIM as (? & u' & TR & SIM & ?).
    apply update_val_rel_nonval_l in H as [_ <-]; etrans.
    exists τ; eexists.
    ssplit.
    * apply trans_τ_interp_state; eauto.
    * intros. step.
      apply split_st'.
      split; apply step_sb'_guard; apply CH; step in SIM.
      apply SIM. symmetry in SIM. apply SIM.
    * now right.
  - apply step_sb'_true_guard_l.
    apply CH.
    now eapply ss_guard_l_inv.
  - (* Vis *)
    specialize (Hh _ e st). destruct Hh as [Hh | Hh].
    + (* pure handler *)
      eapply pure_bind_ctx3_l_sbisim' with
        (P := fun x => trans (val x) (h X0 e st) Stuck).
      cbn. split; auto.
      red. eexists _, _. split; [reflexivity |]. split. {
        intros ?? TRh. apply Hh in TRh as ?.
        eapply wf_val_is_val_inv in H. destruct H as (v & ?).
        2: eapply wf_val_trans; eassumption.
        subst. exists v. split; auto. apply trans_val_inv in TRh as ?. now subs.
      }
      intros [] ?. cbn.
      cbn in SIM. specialize (SIM (obs e x) (k x) ltac:(etrans)).
      destruct SIM as (? & ? & ? & ? & ?).
      apply update_val_rel_nonval_l in H2 as ?; etrans. destruct H3 as (_ & <-).
      eapply epsilon_ctx3_r_sbisim'. cbn. split; auto. red.
      eexists. split.
      * eapply trans_obs_interp_state_pure; eauto.
      * unshelve eapply step_sb'_guard.
        apply equ_clos_st'_ctx.
        apply CH. step in H1. apply H1.
    + (* handler that takes exactly one transition *)
      apply ss_st'_l. split; auto.
      cbn -[RelProd]. intros l t' TR.
      apply trans_bind_inv in TR as [(VAL & th & TRh & EQ) | (x & TRh & TR)].
      2: {
        apply Hh in TRh as []. inversion H; subst; inv_equ.
      }
      apply Hh in TRh as ?. destruct H as [[st' x] EPS].
      simple eapply ss_vis_l_inv in SIM.
      destruct SIM as (l' & u' & TR & SIM & ?).
      apply update_val_rel_nonval_l in H as [_ <-]; etrans.
      exists l, (th;; Guard (interp_state h u' st')). setoid_rewrite EQ. clear t' EQ.
      split; [| split; auto].
      * cbn. apply (trans_obs_interp_state_step h st TR); auto. apply EPS.
      * intros. cbn -[RelProd]. rewrite epsilon_det_bind_ret_l_equ with (x := (st', x)); [| assumption].
        eapply sbt'_clo_bind. {
          instantiate (1 := eq). revert side. apply sbisim_sbisim'.
          eapply Lequiv_sbisim. unfold lift_val_rel.
          rewrite update_val_rel_update_val_rel. rewrite update_val_rel_eq. reflexivity.
          reflexivity.
        }
        intros [] ? <-.
        eapply split_st'.
        split. apply step_sb'_guard. apply CH. step in SIM. apply SIM.
        apply step_sb'_guard. apply CH. symmetry in SIM. step in SIM. apply SIM.
      * right; auto.
  - (* Br *)
    unfold MonadBr_stateT, mbr, MonadBr_ctree. cbn -[RelProd]. rewrite bind_bind, bind_branch.
    apply step_sb'_true_br_l.
    intros.
    eapply ss_br_l_inv in SIM.
    step. rewrite bind_ret_l.
    apply step_sb'_true_guard_l.
    cbn. apply CH. apply SIM.
  Unshelve.
  { cbn. intros.
    eapply equ_clos_st'_goal.
    reflexivity.
    symmetry; apply H2.
    symmetry; apply H3.
    auto.
  }
Qed.

#[global] Instance interp_state_sbisim {E F B C X St}
  {R : relation X} {SYM : Symmetric R}
  `{HasB: B -< C} :
  forall (h : E ~> stateT St (ctree F C)) (Hh : forall X e st, is_simple (h X e st)),
  Proper (sbisim (lift_val_rel R) ==> eq ==> sbisim (lift_val_rel (@eq St * R)%signature))
    (interp_state (C := B) h (T := X)).
Proof.
  cbn -[RelProd]. intros. subst.
  apply sbisim_sbisim'. intros [].
  - apply interp_state_sbisim_aux; auto. step in H. apply H.
  - eapply st'_flip. apply interp_state_sbisim_aux; auto.
    symmetry in H. step in H. apply H.
Qed.

#[global] Instance interp_state_sbisim_eq {E F B C X St}
  `{HasB: B -< C} :
  forall (h : E ~> stateT St (ctree F C)) (Hh : forall X e st, is_simple (h X e st)),
  Proper (sbisim eq ==> eq ==> sbisim eq) (interp_state (C := B) h (T := X)).
Proof.
  intros h Hh t u SIM st st' <-.
  eapply Lequiv_sbisim with (x := lift_val_rel (@eq St * @eq X)%signature).
  eassert (weq (@eq St * @eq X)%signature eq).
  { cbn. unfold RelCompFun. intros [] []; cbn. split; [intros [] | intros [=]]; subst; auto. }
  unfold lift_val_rel. rewrite H; auto. apply update_val_rel_eq.
  eapply interp_state_sbisim; auto.
  eapply Lequiv_sbisim. symmetry. apply update_val_rel_eq. apply SIM.
Qed.

(* The proof that interp preserves sbisim reuses the interp_state proof. *)

#[global] Instance interp_sbisim_eq {E F B C X} `{HasB: B -< C} :
  forall (h : E ~> ctree F C) (Hh : forall X e, is_simple (h X e)),
  Proper (sbisim eq ==> sbisim eq) (interp (B := B) h (T := X)).
Proof.
  intros. cbn. intros.
  rewrite !interp_lift_handler.
  unfold CTree.map. apply sbisim_clo_bind_eq.
  refine (interp_state_sbisim_eq _ _ _ _); auto.
  reflexivity.
Qed.

Arguments get {S E C _}.
Arguments put {S E C _}.
Arguments run_state {S E C} [_] _ _.
Arguments fold_state {E C M S FM MM IM _ _} h g [T].
Arguments interp_state {E C M S FM MM IM BM _ _} h [T].
Arguments refine_state {E C M S FM MM IM _ _ _} g [T].
