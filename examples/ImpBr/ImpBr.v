Unset Universe Checking.

From Coq Require Import
     Arith.PeanoNat
     Lists.List
     Strings.String
     Morphisms
     Setoid
     RelationClasses.

From ExtLib Require Import
     Data.String
     Structures.Monad
     Structures.Traversable
     Data.Monads.StateMonad
     Data.List
     Data.Map.FMapAList.

From ITree Require Import
     ITree
     Basics.CategoryKleisli
     Events.State
     Events.MapDefault.

From Coinduction Require Import all.

From CTree Require Import
     CTree
     Eq
     Misc.Pure
     Interp.Fold
     Interp.FoldCTree
     Interp.FoldStateT.

Import ListNotations.
Import MonadNotation.
Local Open Scope monad_scope.
Local Open Scope string_scope.

(*|
Imp manipulates a countable set of variables represented as [string]s:
|*)
Definition var : Set := string.

(*|
For simplicity, the language manipulates [nat]s as values.
|*)
Definition value : Type := nat.

Inductive expr : Type :=
| Var (_ : var)
| Lit (_ : value)
| Plus  (_ _ : expr)
| Minus (_ _ : expr)
| Mult  (_ _ : expr).

(*|
Imp with a non-deterministic branching statement
|*)
Inductive stmt : Type :=
| Assign (x : var) (e : expr)    (* x = e *)
| Seq    (a b : stmt)            (* a ; b *)
| If     (i : expr) (t e : stmt) (* if (i) then { t } else { e } *)
| While  (t : expr) (b : stmt)   (* while (t) { b } *)
| Branch (a b : stmt)            (* br { a } or { b } *)
| Skip                           (* ; *)
| Block
.

Variant MemE : Type -> Type :=
| rd (x : var) : MemE value
| wr (x : var) (v : value) : MemE unit.

Section Semantics.

  Notation computation := (ctree MemE B2).

  Fixpoint denote_expr (e : expr) : computation value :=
    match e with
    | Var v     => trigger (rd v)
    | Lit n     => ret n
    | Plus a b  => l <- denote_expr a ;; r <- denote_expr b ;; ret (l + r)
    | Minus a b => l <- denote_expr a ;; r <- denote_expr b ;; ret (l - r)
    | Mult a b  => l <- denote_expr a ;; r <- denote_expr b ;; ret (l * r)
    end.

  Definition while (step : computation (unit + unit)) : computation unit :=
    CTree.iter (fun _ => step) tt.

  Definition is_true (v : value) : bool := if (v =? 0)%nat then false else true.

  Fixpoint denote_imp (s : stmt) : computation unit :=
    match s with
    | Assign x e =>  v <- denote_expr e ;; trigger (wr x v)
    | Seq a b    =>  denote_imp a ;; denote_imp b
    | If i t e   =>
      v <- denote_expr i ;;
      if is_true v then denote_imp t else denote_imp e

    | While t b =>
      while (v <- denote_expr t ;;
	         if is_true v
             then denote_imp b ;; ret (inl tt)
             else ret (inr tt))

    | Branch a b => br2 (denote_imp a) (denote_imp b)

    | Skip => ret tt

    | Block => Stuck

    end.

  (* list of key value pairs *)
  Definition env := alist var value.

  Definition handle_imp : MemE ~> Monads.stateT env (ctree void1 B2) :=
    fun _ e s =>
      match e with
      | rd x => Ret (s, lookup_default x 0 s)
      | wr x v => Ret (Maps.add x v s, tt)
      end.

  Definition interp_imp (t : computation _) : Monads.stateT env (ctree void1 B2) unit :=
    interp_state handle_imp t.

End Semantics.
Notation "⟦ c ⟧" := (denote_imp c).
Notation "'ℑ' c" := (interp_imp (denote_imp c)) (at level 10).

Section Theory.

(*|
  Given the direct translation of the [Branch] construction, the
  primitive equational theory that we have at the [ctree] level is
  straightforwardly lifted to the language level, more specifically
  at the level of uninterpreted ctrees.
|*)
  Lemma branch_commut : forall (a b : stmt),
      ⟦Branch a b⟧ ~ ⟦Branch b a⟧.
  Proof.
    intros; apply br2_commut.
  Qed.

  Lemma branch_assoc : forall (a b c : stmt),
      ⟦Branch a (Branch b c)⟧ ~ ⟦Branch (Branch a b) c⟧.
  Proof.
    intros; cbn.
    now rewrite br2_assoc.
  Qed.

  Lemma branch_idem : forall a : stmt,
      ⟦Branch a a⟧ ~ ⟦a⟧.
  Proof.
    intros; apply br2_idem.
  Qed.

  Lemma branch_congr : forall a a' b b',
      ⟦a⟧ ~ ⟦a'⟧ ->
      ⟦b⟧ ~ ⟦b'⟧ ->
      ⟦Branch a b⟧ ~ ⟦Branch a' b'⟧.
  Proof.
    intros. cbn. apply sb_br_id.
    intro; destruct x; rewrite ?H, ?H0; reflexivity.
  Qed.

  Lemma branch_block_l : forall a : stmt,
      ⟦Branch Block a⟧ ~ ⟦a⟧.
  Proof.
    intros; apply br2_stuck_l.
  Qed.

  Lemma branch_block_r : forall a : stmt,
      ⟦Branch a Block⟧ ~ ⟦a⟧.
  Proof.
    intros; apply br2_stuck_r.
  Qed.

(*|
  Strong bisimilarity at the uninterpreted level can be transported
  freely after interpretation via [interp_state_sbisim].
  For instance here transporting [branch_block_r].
|*)

  #[global] Instance handle_imp_is_simple :
    forall (X : Type) (e : MemE X) (s : env), is_simple (E := void1) (handle_imp _ e s).
  Proof.
    unfold handle_imp, h_state. intros. destruct e; typeclasses eauto.
  Qed.

  Lemma branch_block_r_interp : forall (a : stmt) s,
    ℑ (Branch a Block) s ~
    ℑ a s.
  Proof.
    intros.
    unfold interp_imp.
    rewrite branch_block_r. reflexivity.
  Qed.

  Lemma filter_filter : forall {A} f (l : list A), filter f (filter f l) = filter f l.
  Proof.
    intros. induction l.
    - reflexivity.
    - cbn. destruct (f a) eqn:?.
      + cbn. rewrite Heqb. f_equal. apply IHl.
      + apply IHl.
  Qed.

  Lemma alist_add_alist_add : forall {K RD_K V}, RelDec.RelDec_Correct (RD_K) ->
    forall k v v' l, @alist_add K eq RD_K V k v (alist_add _ k v' l) = alist_add _ k v l.
  Proof.
    intros. unfold alist_add, alist_remove. cbn. rewrite filter_filter.
    rewrite RelDec.rel_dec_eq_true; auto.
  Qed.

(*|
Finally, we can put bits together to prove that the programs [p3] and [br p2 or p3]
from Section 2 are indeed equivalent.
|*)
  Example branch_ex : forall s : env,
      ℑ (Branch
           (Seq
              (Assign "x" (Lit 0))
              (Assign "x" (Lit 1)))
           Block) s ~
        ℑ (Assign "x" (Lit 1)) s.
  Proof with (unfold interp_imp).
    intros...
    rewrite branch_block_r_interp...
    rewrite 2 unfold_interp_state.
    cbn.
    repeat setoid_rewrite bind_ret_l.
    repeat setoid_rewrite sb_guard.
    cbn.
    rewrite interp_state_ret.
    unfold trigger. rewrite interp_state_vis.
    cbn. rewrite bind_ret_l, sb_guard.
    cbn. rewrite interp_state_ret.
    apply sb_ret.
    rewrite alist_add_alist_add; [reflexivity |].
    apply RelDec_Correct_string.
  Qed.

End Theory.
