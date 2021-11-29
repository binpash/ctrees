From CTree Require Import
	CTrees Equ Bisim.

From ITree Require Import
	ITree Eq.

From Coq Require Import
	Morphisms Program.

From Paco Require Import paco.

From Coinduction Require Import
	coinduction rel tactics.

Open Scope ctree.

Definition embed {E X} : itree E X -> ctree E X :=
	cofix _embed t :=
	 match observe t with
	| RetF x => CTrees.Ret x
	| TauF t => CTrees.Tau (_embed t)
	| VisF e k => CTrees.Vis e (fun x => _embed (k x))
	 end.

Notation "'_embed' ot" :=
	(match ot with
	| RetF x => CTrees.Ret x
	| TauF t => CTrees.Tau (embed t)
	| VisF e k => CTrees.Vis e (fun x => embed (k x))
 end) (at level 50, only parsing).

(* Painfully ad-hoc patch to avoid 30s of unification... *)
#[global] Instance Reflexive_equ {E R}: Reflexive (gfp (@fequ E R _ eq)).
Proof. apply Equivalence_equ.  Qed.

Lemma embed_unfold {E X} (t : itree E X) :
	equ eq (embed t) (_embed (observe t)).
Proof.
	(* Warning, if Bisim is in scope and we don't have the instance above, this takes 30 seconds *)
  now step.
Qed.

#[local] Notation iobserve := observe.
#[local] Notation _iobserve := _observe.
#[local] Notation cobserve := CTrees.observe.
#[local] Notation _cobserve := CTrees._observe.
#[local] Notation iRet x   := (Ret x).
#[local] Notation iVis e k := (Vis e k).
#[local] Notation iTau t   := (Tau t).
#[local] Notation cRet x   := (CTrees.Ret x).
#[local] Notation cTau t   := (CTrees.Tau t).
#[local] Notation cVis e k := (CTrees.Vis e k).

Lemma embed_eq {E X}:
	Proper (eq_itree eq ==> equ eq) (@embed E X).
Proof.
	unfold Proper, respectful.
	coinduction r CIH.
	intros t u bisim.
	rewrite 2 embed_unfold.
	punfold bisim.
	inv bisim; pclearbot; try easy.
	- constructor; intros _.
		apply CIH, REL.
	- constructor; intros.
		apply CIH, REL.
Qed.


Lemma embed_eutt {E X}:
  Proper (eutt eq ==> bisim) (@embed E X).
Proof.
Admitted.

(* Maybe simpler to just write a coinductive relation *)
Definition partial_inject {E X} : ctree E X -> itree E (option X) :=
	cofix _inject t :=
	 match CTrees.observe t with
	| CTrees.RetF x => Ret (Some x)
	| @ChoiceF _ _ _ _ n t =>
		(match n as x return n = x -> itree E (option X) with
					 | O => fun _ => Ret None
					 | 1 => fun pf => eq_rect_r
	 													(fun n1 : nat => (Fin.t n1 -> ctree E X) -> itree E (option X))
	 													(fun t2 : Fin.t 1 -> ctree E X => Tau (_inject (t2 Fin.F1)))
	 													pf t
					 | _ => fun _ => Ret None
		 end eq_refl)
	| CTrees.VisF e k => Vis e (fun x => _inject (k x))
	 end.

Definition option_rel {A B : Type} (R : A -> B -> Prop) : option A -> option B -> Prop :=
	fun x y => match x, y with
	|	Some x, Some y => R x y
	| _, _ => False
	end.

(* This is probably false: no reason for the embedding to succeed. *)
Lemma partial_inject_eq {E X} :
	Proper (equ eq ==> eq_itree (option_rel eq)) (@partial_inject E X).
Admitted.

Lemma partial_inject_eutt {E X} :
	Proper (bisim ==> eutt (option_rel eq)) (@partial_inject E X).
Admitted.

Variant is_detF {E X} (is_det : ctree E X -> Prop) : ctree E X -> Prop :=
| Ret_det : forall x, is_detF is_det (CTrees.Ret x)
| Vis_det : forall {Y} (e : E Y) k,
	(forall y, is_det (k y)) ->
	is_detF is_det (CTrees.Vis e k)
| Tau_det : forall t,
	(is_det t) ->
	is_detF is_det (CTrees.Tau t)
.

Definition is_det {E X} := paco1 (@is_detF E X) bot1.