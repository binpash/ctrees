From Coq Require Import List.
From ITree Require Import
     Core.Subevent
     Indexed.Sum.

From CTree Require Import
     CTree
     Logic.Kripke
     Interp.Preempt.

From ExtLib Require Import
     Structures.Monads
     Structures.MonadState
     Data.Monads.StateMonad.

Import ListNotations MonadNotation.
Local Open Scope list_scope.
Local Open Scope monad_scope.

Set Implicit Arguments.

(*| Unique thread identifiers |*)
Notation uid := nat.

(*| Modify the nth element of a list if it exists |*)
Fixpoint nth_map{A}(f: A -> A)(l: list A)(i: nat) : list A :=
  match l, i with
  | h::ts, 0 => f h :: ts
  | _::ts, S n => nth_map f ts n
  | [], _ => []
  end.

(*| Message passing |*)
Section Messaging.

  Context (T: Type).

  (*| Network effects |*)
  Inductive netE: Type -> Type :=
  | Recv: netE (option T)
  | Send : uid -> T -> netE unit.

  Notation Qs := (list (list T))  (only parsing).

  (*| This determines how we observe parallel message passing processes in our Logic |*)
  #[global] Instance handler_network_par: (netE +' parE) ~~> state (Qs * uid) :=
    fun X e =>
      '(qs, i) <- get;;
      match e with
      |inl1 s => 
         match s in netE Y return X = Y -> state (Qs * uid) Y with
         | Recv => fun _: X = option T =>                          
                    match nth_error qs i with
                    | None | Some [] => ret None
                    | Some (msg :: ts) =>
                        put (nth_map (fun _ => ts) qs i, i);;
                        ret (Some msg)
                    end
         | Send to msg => fun _ => put (nth_map (fun q => q ++ [msg]) qs to, i)
         end eq_refl
      | inr1 s =>
          match s in parE Y return X = Y -> state (Qs * uid) Y with
          | Switch i' => fun _ => put (qs, i')
          end eq_refl
      end.
  
End Messaging.

Arguments Recv {T}.
Arguments Send {T}.

Definition recv {T E C} `{netE T -< E}: ctree E C (option T) :=
  trigger Recv.
Definition send {T E C} `{netE T -< E}: uid -> T -> ctree E C unit :=
  fun u p => trigger (Send u p). 

(* Fairness proof for [rr] *)
From CTree Require Import Ctl.
Import CtlNotations.
Local Open Scope ctl_scope.

Unset Universe Checking.
Lemma fair_rr{E C X S} {s: S} `{HasStuck: B0 -< C} `{HasTau: B1 -< C}
      `{h: E ~~> state S}: forall (l: list (ctree E C X)),
    @entailsF (E +' parE) C (list (ctree E C X)) (S * nat) _ _
              <(AG (AF (now {fun '(_,i) => i = length l})))>
              (rr l: ctree (E +' parE) C (list (ctree E C X)))              
              (s, 0).
  Proof.
  intro sys; unfold rr; cbn.
  induction sys; cbn.
  - coinduction R CIH.
    apply RStepA.
    apply MatchA; auto.

Admitted.
