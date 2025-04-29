import Error "mo:base/Error";
import Nat32 "mo:base/Nat32";
module {
  public type Type = { message : Text; error_code : Nat };

  public type Generic = { #GenericError : Type };
  public type Result = { #Err : Generic };

  public func code(e : Error.Error) : Nat = switch (Error.code(e)) {
    case (#call_error code) Nat32.toNat(code.err_code);
    case (#system_fatal) 5000;
    case (#system_transient) 5001;
    case (#system_unknown) 5002;
    case (#destination_invalid) 5003;
    case (#canister_reject) 5004;
    case (#canister_error) 5005;
    case (#future _f) 5006;
  };

  public func error(e : Error.Error) : Result = #Err(convert(e));
  public func convert(e : Error.Error) : Generic = generic(Error.message(e), code(e));
  public func generic(message : Text, error_code : Nat) : Generic = #GenericError {
    message;
    error_code;
  };
  public func text(t : Text) : Result = #Err(generic(t, 0));

  public type GenericBatch = { #GenericBatchError : Type };
  public type BatchResult = { #Err : GenericBatch };

  public func errorBatch(e : Error.Error) : BatchResult = #Err(convertBatch(e));
  public func convertBatch(e : Error.Error) : GenericBatch = genericBatch(Error.message(e), code(e));
  public func genericBatch(message : Text, error_code : Nat) : GenericBatch = #GenericBatchError {
    message;
    error_code;
  };
  public func textBatch(t : Text) : BatchResult = #Err(genericBatch(t, 0));
};
