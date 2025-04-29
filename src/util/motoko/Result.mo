module {
  public type Type<OkType, ErrorType> = {
    #Ok : OkType;
    #Err : ErrorType;
  };
};
