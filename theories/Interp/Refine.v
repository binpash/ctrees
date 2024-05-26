From ExtLib Require Import
     Structures.Functor
     Structures.Monad.

Unset Universe Checking.
From CTree Require Import
     Eq
     Eq.Epsilon
     Eq.SSimAlt
     Interp.Fold
     Interp.FoldCTree
     Interp.FoldStateT
     Misc.Pure.

Import ITree.Basics.Basics.Monads.
Import MonadNotation.
Open Scope monad_scope.

(*Definition refine' {E C M : Type -> Type}
           {FM : Functor M} {MM : Monad M}
           {IM : MonadIter M} {FoM : MonadTrigger E M}
           {CM : MonadBr void1 M}
           (h : C ~> M) :
  ctree E (B01 +' C) ~> M :=
  refine (fun b X (c: C X) =>
    match c, X return M X with
    | inl1 c, X => mbr b (inl1 c)
    | inr1 c, X => r <- h X c;; mbr b (inl1 (inr1 branch1));; ret r
    end).

Definition refine'_state {E C D St} (f : C ~> stateT St (ctree E (B01 +' D))) :
  ctree E (B01 +' C) ~> stateT St (ctree E (B01 +' D)) :=
  refine' (CM := MonadBr_stateT) f.*)

Theorem ssim_pure {E F B C X} : forall (L : rel _ _) (t : ctree E B X),
  pure_finite t ->
  (forall x : X, L (val x) (val tt)) ->
  ssim L t (Ret tt : ctree F C unit).
Proof.
  intros. induction H; subs.
  - now apply ssim_ret.
  - now apply Stuck_ssim.
  - now apply ssim_br_l.
  - now apply ssim_guard_l.
Qed.

Unset Universe Checking.

Theorem refine_ctree_ssim {E B B' X} :
  forall (t : ctree E B X) (h : B ~> ctree E B'),
  (forall X c, pure_finite (h X c)) ->
  refine h t ≲ t.
Proof.
  intros. rewrite ssim_ssim'. red. revert t. coinduction R CH. intros.
  rewrite (ctree_eta t) at 2.
  setoid_rewrite unfold_refine. cbn.
  destruct (observe t) eqn:?.
  - apply step_ssbt'_ret. reflexivity.
  - apply step_ss'_stuck.
  - apply step_ss'_step; auto.
    step. now apply step_ss'_guard_l.
  - now apply step_ss'_guard.
  - setoid_rewrite bind_trigger.
    apply step_ss'_vis_id. intros. split; [|auto].
    step. apply step_ss'_guard_l. apply CH.
  - change (Br c k) with ((fun _ => Br c k) tt).
    setoid_rewrite <- bind_ret_l at 6.
    eapply ss'_clo_bind with (R0 := (fun _ _ => True)).
    { apply ssim_pure. apply H. intros. now constructor. }
    intros ? _ _. cbn.
    apply step_ss'_br_r with (x := x).
    apply step_ss'_guard_l. apply CH.
Qed.

Definition Rrr {St X} (p : St * X) (x : X) := snd p = x.
Definition Lrr {St E X} := @lift_val_rel E _ X (@Rrr St X).

Theorem refine_state_ssim {E B B' X St} :
  forall (t : ctree E B X) (h : B ~> stateT St (ctree E B')),
  (forall X c s, pure_finite (h X c s)) ->
  forall s, refine h t s (≲@Lrr St E X) t.
Proof.
  intros. rewrite ssim_ssim'. red. revert t s. coinduction R CH. intros.
  rewrite (ctree_eta t) at 2.
  setoid_rewrite unfold_refine_state. cbn.
  destruct (observe t) eqn:?.
  - apply step_ssbt'_ret. constructor. reflexivity.
  - apply step_ss'_stuck.
  - apply step_ss'_step; auto.
    red. constructor; etrans.
    step. apply step_ss'_guard_l.
    apply CH.
  - apply step_ss'_guard. apply CH.
  - setoid_rewrite bind_trigger.
    apply step_ss'_vis_id. intros. split; [| constructor; etrans].
    step. apply step_ss'_guard_l. apply CH.
  - change (Br c k) with ((fun _ => Br c k) tt).
    setoid_rewrite <- bind_ret_l at 6.
    eapply ss'_clo_bind with (R0 := (fun _ _ => True)).
    { apply ssim_pure. apply H. intros. now constructor. }
    intros ? _ _. cbn.
    apply step_ss'_br_r with (x := snd x).
    apply step_ss'_guard_l. apply CH.
Qed.
