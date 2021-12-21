From Coq Require Import
     Program
     List
     Logic.FunctionalExtensionality.

Require Import Coq.micromega.Lia.

From CTree Require Import
	   Utils
	   CTrees
 	   Interp
	   Equ
	   Bisim
     Shallow.

From ITree Require Import
     Sum.

From Coinduction Require Import
	coinduction rel tactics.

Import ListNotations.
Import CTreeNotations.

Variant yieldE S : Type -> Type :=
| Yield : S -> yieldE S S.

Variant spawnE : Type -> Type :=
| Spawn : spawnE bool.

(* Fixpoint remove_at {A} {n : nat} {H : n > 0} (l : fin n -> A) (i : fin n) : fin (n - 1) -> A := *)
(*   fun (i' : fin (n - 1)) => *)
(*     _ *)
(* . *)


(** return one of the elements in [x :: xs], as well as the complete list of unchosen elements *)
Fixpoint choose' {E} {X} (x : X) (xs : list X) (rest : list X) :
  ctree E (X * list X)
  := match xs with
     | [] => Ret (x, rest)
     | x' :: xs =>
         choiceI2
         (Ret (x, (x' :: xs) ++ rest)) (* [x] *)
         (choose' x' xs (x :: rest)) (* not [x] *)
     end.
Definition choose {E} {X} (x : X) (xs : list X) : ctree E (X * list X) :=
  choose' x xs [].

Section parallel.
  Context {config : Type}.

  Definition parE c := yieldE c +' spawnE.

  Definition thread := Monads.stateT config
                                     (ctree (parE config))
                                     unit.

  Definition completed := Monads.stateT config (ctree void1) unit.

  Definition schedule_match schedule (curr : thread) (rest : list thread)
    : completed :=
    fun (s : config) =>
      match (observe (curr s)) with
      | RetF (s', _) => match rest with
                       | [] => Ret (s', tt)
                       | h :: t => '(curr', rest') <- choose h t;;
                                 TauI (schedule curr' rest' s')
                       end
      | ChoiceF b n k => Choice b n (fun c => (schedule (fun _ => k c) rest s))
      | VisF (inl1 e) k =>
          match e in yieldE _ C return (C -> ctree (parE config) (config * unit)) -> _ with
          | Yield _ s' =>
              fun k =>
                '(curr', rest') <- choose k rest;;
                TauI (schedule curr' rest' s')
          end k
      | VisF (inr1 e) k =>
          match e in spawnE R return (R -> ctree (parE config) (config * unit)) -> _ with
          | Spawn =>
              fun k =>
                TauI (schedule (fun _ => k false) ((fun _ => k true) :: rest) s) (* this s doesn't matter, since the running thread won't use it *)
          end k
      end.
  CoFixpoint schedule := schedule_match schedule.
  Lemma rewrite_schedule curr rest s : schedule curr rest s ≅ schedule_match schedule curr rest s.
  Proof.
    step. eauto.
  Qed.

  Fixpoint list_relation {T} (P : relation T) (l1 l2 : list T) : Prop :=
    match l1, l2 with
    | [], [] => True
    | h1 :: t1, h2 :: t2 => P h1 h2 /\ list_relation P t1 t2
    | _, _ => False
    end.

  #[global] Instance list_relation_refl {T} (P : relation T)
        `{Reflexive _ P} :
    Reflexive (list_relation P).
  Proof.
    repeat intro. induction x; auto. split; auto.
  Qed.

  Lemma list_relation_app {T} (P : relation T) l1 l2 r1 r2 :
    list_relation P l1 l2 ->
    list_relation P r1 r2 ->
    list_relation P (l1 ++ r1) (l2 ++ r2).
  Proof.
    revert l2.
    induction l1; destruct l2; intros Hl Hr; inv Hl; try split; auto.
  Qed.

  Lemma equ_schedule_helper k1 k2 l1 l2 s r
        (CIH : forall (x y : config -> ctree (parE config) (config * ()))
                 (x0 y0 : list (config -> ctree (parE config) (config * ())))
                 (y1 : config),
            pointwise_relation config (equ eq) x y ->
            list_relation (pointwise_relation config (equ eq)) x0 y0 ->
            t_equ eq r (schedule x x0 y1) (schedule y y0 y1)) :
    forall r1 r2,
    pointwise_relation config (equ eq) k1 k2 ->
    list_relation (pointwise_relation _ (equ eq)) l1 l2 ->
    list_relation (pointwise_relation _ (equ eq)) r1 r2 ->
    equF eq (t_equ eq r)
         (observe ('(curr', rest') <- choose' k1 l1 r1;;
                   TauI (schedule curr' rest' s)))
         (observe ('(curr', rest') <- choose' k2 l2 r2;;
                   TauI (schedule curr' rest' s))).
  Proof.
    revert l2 k1 k2.
    induction l1; destruct l2; intros k1 k2 r1 r2 Hk Hl Hr; inv Hl.
    - cbn. constructor. intros; auto.
    - cbn. constructor. intros [].
      + step. cbn. constructor. intros. apply CIH; auto. constructor; auto.
        apply list_relation_app; auto.
      + step. eapply IHl1; eauto. constructor; auto.
  Qed.

  #[global] Instance equ_schedule :
    Proper ((pointwise_relation _ (equ eq)) ==> (list_relation (pointwise_relation _ (equ eq))) ==> eq ==> equ eq)
           schedule.
  Proof.
    repeat intro. subst. revert H H0. revert x y x0 y0 y1. coinduction r CIH. intros t1 t2 l1 l2 c Ht Hl.
    do 2 rewrite rewrite_schedule. unfold schedule_match. simpl.
    specialize (Ht c). step in Ht. inv Ht; eauto. 2: destruct e.
    - destruct y. destruct l1, l2; inv Hl; auto.
      apply equ_schedule_helper; auto.
    - clear H H0. destruct y.
      unfold choose.
      apply equ_schedule_helper; auto.
    - destruct s. constructor. intros. apply CIH.
      + intro. apply REL.
      + constructor; auto. intro. auto.
    - cbn. constructor. intros. apply CIH; auto.
      intro. apply REL.
  Qed.

  Definition vec n := fin n -> thread.

  Fixpoint remove_front_vec {n : nat} (v : vec (S n)) : vec n :=
    fun i => v (Fin.FS i).

  Program Fixpoint remove_vec {n : nat} (v : vec (S n)) (i : fin (S n)) : vec n :=
    match i with
    (* this is the one we're removing, so bump [i'] by one *)
    | Fin.F1 => remove_front_vec v
    (* not yet at the index we want to ignore *)
    | Fin.FS j => fun i' =>
                   match i' with
                   | Fin.F1 => v Fin.F1
                   | Fin.FS j' => remove_vec (remove_front_vec v) j j'
                   end
    end.

  Definition replace_vec {n : nat} (v : vec n) (i : fin n) (t : thread) : vec n :=
    fun i' => if Fin.eqb i i' then t else v i'.

  Program Definition append_vec {n : nat} (v : vec n) (t : thread) : vec (S n) :=
    fun i => let i' := Fin.to_nat i in
          match PeanoNat.Nat.eqb (`i') n with
          | true => t
          | false => v (@Fin.of_nat_lt (`i') _ _)
          end.
  Next Obligation.
    (* why is the space after ` necessary...... *)
    assert ((` (Fin.to_nat i)) <> n).
    {
      pose proof (Bool.reflect_iff _ _ (PeanoNat.Nat.eqb_spec (` (Fin.to_nat i)) n)).
      intro. rewrite H in H0. rewrite H0 in Heq_anonymous. inv Heq_anonymous.
    }
    pose proof (proj2_sig (Fin.to_nat i)).
    simpl in H0. lia.
  Defined.

  Definition schedule'_match
          (schedule' : forall (n : nat), vec n -> vec n)
          (n : nat)
          (v: vec n)
    : vec n.
    refine
      (fun (i : fin n) s =>
         match (observe (v i s)) with
         | RetF (s', _) =>
           match n as m return n = m -> _ with
           | 0 => _
           | S n' => match n' as m return n' = m -> _ with
                   | 0 => fun H1 H2 => Ret (s', tt)
                   | S n'' => fun H1 H2 => ChoiceI
                                       n'
                                       (fun i' => schedule' n' (remove_vec _ _) i' s')
                   end (eq_refl n')
           end (eq_refl n)
         | ChoiceF b n' k => Choice b n' (fun c => schedule' n (replace_vec v i (fun _ => k c)) i s)
         | VisF (inl1 e) k =>
           match e in yieldE _ R return (R -> ctree (parE config) (config * unit)) -> _ with
           | Yield _ s' =>
             fun k => ChoiceI
                     n
                     (fun i' => schedule' n (replace_vec v i k) i' s')
           end k
         | VisF (inr1 e) k =>
           match e in spawnE R return (R -> ctree (parE config) (config * unit)) -> _ with
           | Spawn =>
             fun k =>
               TauI (schedule'
                       (S n)
                       (append_vec (replace_vec v i (fun _ => k false)) (fun _ => k true))
                       (* The [i] here means that we don't yield at a spawn *)
                       (Fin.L_R 1 i) (* view [i] as a [fin (n + 1)] *)
                       s) (* this [s] doesn't matter, since the running thread won't use it *)
           end k
         end).
    - intro. subst. inv i.
    - subst. apply v.
    - subst. apply i.
  Defined.

  CoFixpoint schedule' := schedule'_match schedule'.

End parallel.
