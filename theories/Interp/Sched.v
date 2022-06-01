From ExtLib Require Import
     Structures.Functor
     Structures.Monad.

From CTree Require Import
     Eq
     Interp.State.

Import ITree.Basics.Basics.Monads.
Import MonadNotation.
Open Scope monad_scope.

#[global] Instance stateT_trigger {E S M} {MM : Monad M} {MT: MonadTrigger E M} :
  MonadTrigger E (stateT S M) :=
  fun _ e s => v <- mtrigger _ e;; ret (s, v).

Definition schedule {E M : Type -> Type}
					 {FM : Functor M} {MM : Monad M} {IM : MonadIter M} {FoM : MonadTrigger E M}
           {CM : MonadChoice M}
           (h : bool -> forall n, M (fin n)) :
	ctree E ~> M :=
  fun R =>
		iter (fun t =>
				    match observe t with
				    | RetF r => ret (inr r)
				    | @ChoiceF _ _ _ b n k =>
                bind (h b n) (fun x => ret (inl (k x)))
				    | VisF e k => bind (mtrigger _ e) (fun x => ret (inl (k x)))
				    end).

Variant pureb {E X} (rec : ctree E X -> Prop) : ctree' E X -> Prop :=
  | pure_ret   (v : X) : pureb rec (RetF v)
  | pure_delay n k (REC: forall v, rec (k v)) : pureb rec (ChoiceIF n k).
#[global] Hint Constructors equb: core.

Definition pureb_ {E X} rec (t : ctree E X) := pureb rec (observe t).

Program Definition fpure {E R} : mon (ctree E R -> Prop) := {|body := pureb_|}.
Next Obligation.
  red in H0 |- *.
  inversion_clear H0; econstructor; auto.
Qed.

Definition pure {E R} := gfp (@fpure E R).

(* Definition schedule_pure {E} (hV hI : forall n, fin n) : ctree E ~> ctree E := *)
(*   schedule (fun n => Ret (h n)). *)

#[global] Instance schedule_equ {E X} h :
  Proper (@equ E X X eq ==> equ eq) (schedule h X).
Proof.
  cbn.
  coinduction R CH.
  intros. setoid_rewrite unfold_iter.
  step in H. inv H.
  - setoid_rewrite bind_ret_l. reflexivity.
  - setoid_rewrite bind_bind. setoid_rewrite bind_trigger.
    constructor. intros.
    setoid_rewrite bind_ret_l.
    step. constructor. intros _.
    apply CH. apply REL.
  - setoid_rewrite bind_bind.
    upto_bind_eq.
    setoid_rewrite bind_ret_l.
    constructor. intros _.
    apply CH. apply REL.
Qed.

Definition schedule_cst {E} (h : bool -> forall n, fin (S n)) : ctree E ~> ctree E :=
  schedule (fun b n =>
    match n with
    | O => CTree.stuck b
    | S n => Choice b 1 (fun _ => Ret (h b n))
    end).

Definition round_robin {E} : ctree E ~> stateT nat (ctree E).
Proof.
  refine (schedule
            (fun b n m =>
               (* m: branch to be scheduled
                  n: arity of the new node
                *)
               match n as n' return (ctree E (nat * fin n')) with
               | O => CTree.stuck b
               | S n => (Ret (S m, @Fin.of_nat_lt (Nat.modulo m (S n)) _ _))
               end
         )).
  apply (NPeano.Nat.mod_upper_bound).
  auto with arith.
Defined.

Theorem schedule_cst_refinement :
  forall {E X} (h : bool -> forall n, fin (S n)) (t : ctree E X),
  schedule_cst h _ t ≲ t.
Proof.
  intros until h. coinduction R CH. repeat intro.
  do 3 red in H. remember (observe _) as os. genobs t' ot'.
  assert (EQ : go os ≅ schedule_cst h X t \/ go os ≅ TauI (schedule_cst h X t)).
  { left. rewrite Heqos. now rewrite <- ctree_eta. } clear Heqos.
  apply (f_equal go) in Heqot'. eq2equ Heqot'.
  rewrite <- ctree_eta in EQ0.
  assert (exists u' : Trans.SS, trans l t u' /\ sst R t' u').
  2: { destruct H0; exists x; destruct H0; assumption. }
  setoid_rewrite <- EQ0. clear t' EQ0.
  revert t EQ.
  induction H; intros; subst.
  - destruct EQ as [EQ|EQ]; symmetry in EQ.
    setoid_rewrite unfold_iter in EQ.
    setoid_rewrite (ctree_eta t0).
    genobs t0 ot0. clear t0 Heqot0.
    destruct ot0 eqn:?; subst.
    + step in EQ. inv EQ.
    + step in EQ. inv EQ.
    + setoid_rewrite bind_bind in EQ.
      setoid_rewrite bind_ret_l in EQ.
      change t with (observe (go t)) in H.
      rewrite trans__trans in H.
      destruct n0.
      * setoid_rewrite bind_choice in EQ.
        apply equ_choice_invT in EQ as ?. destruct H0 as [<- _].
        now eapply Fin.case0.
      * setoid_rewrite bind_choice in EQ.
        apply equ_choice_invT in EQ as ?. destruct H0 as [<- _].
        destruct vis. { step in EQ. inv EQ. }
        simple eapply equ_choice_invE with (x := x) in EQ.
        rewrite bind_ret_l in EQ.
        lapply (IHtrans_ (k0 (h false n0))).
        -- intro. destruct H0 as (? & ? & ?).
           etrans.
        -- right. rewrite <- ctree_eta. now rewrite <- EQ.
    + apply IHtrans_. left.
      apply equ_choice_invT in EQ as ?. destruct H0 as [<- _]. rewrite <- ctree_eta.
      simple apply equ_choice_invE with (x := x) in EQ. now rewrite EQ.
  - destruct EQ. 2: { step in H0. inv H0. }
    setoid_rewrite unfold_iter in H0. cbn in H0.
    destruct (observe t0) eqn:?;
      (try setoid_rewrite bind_choice in H0);
      (try setoid_rewrite bind_trigger in H0);
      (try destruct vis);
      subst; try now step in H0; inv H0.
    rewrite bind_bind in H0.
    destruct n0.
    + setoid_rewrite bind_choice in H0.
      apply equ_choice_invT in H0 as ?. destruct H1 as [-> _].
      now eapply Fin.case0.
    + rewrite bind_choice in H0.
      do 2 setoid_rewrite bind_ret_l in H0.
      apply equ_choice_invT in H0 as ?. destruct H1 as [-> _].
      simple apply equ_choice_invE with (x := x) in H0.
      exists (k0 (h true n0)).
      rewrite ctree_eta, Heqc. split; etrans.
      rewrite <- H, H0, <- ctree_eta, sb_tauI.
      apply CH.
    + destruct n0; step in H0; inv H0.
  - destruct EQ. 2: { step in H0. inv H0. }
    setoid_rewrite unfold_iter in H0. cbn in H0.
    destruct (observe t0) eqn:?;
      try ((try destruct n); now step in H0; inv H0).
    setoid_rewrite bind_trigger in H0. setoid_rewrite bind_vis in H0.
    apply equ_vis_invT in H0 as ?. destruct H1.
    apply equ_vis_invE in H0 as [-> ?].
    setoid_rewrite bind_ret_l in H0.
    exists (k0 x). eexists.
    { rewrite ctree_eta, Heqc. etrans. }
    rewrite <- H, H0, <- ctree_eta, sb_tauI. apply CH.
  - destruct EQ. 2: { step in H. inv H. }
    exists CTree.stuckI.
    setoid_rewrite unfold_iter in H.
    destruct (observe t) eqn:?;
      try ((try destruct n); now step in H; inv H).
    setoid_rewrite bind_ret_l in H.
    + step in H. inv H. rewrite ctree_eta, Heqc.
      split; etrans. rewrite choice0_always_stuck. reflexivity.
Qed.
