unit slog;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows, System.JSON, System.Variants, System.Rtti, System.TypInfo,
  System.DateUtils, System.StrUtils, System.Types, System.IOUtils;

type
  TLogLevel = (llDebug, llInfo, llWarn, llError);

  TFormatOptions = record
    MaxDepth: Integer;
    MaxElements: Integer;
    ShowClassNames: Boolean;
    ShowTypeInfo: Boolean;
    ShowNilValues: Boolean;
    ShowEmptyCollections: Boolean;
    DateTimeFormat: string;
    FloatPrecision: Integer;
    IndentString: string;

    class function Default: TFormatOptions; static;
  end;

  TAttr = record
    Key: string;
    Value: Variant;
    TypeInfo: PTypeInfo;
    RawData: Pointer;
    class function Create(const AKey: string; const AValue: Variant): TAttr; overload; static;
    class function Create(const AKey: string; const AValue; ATypeInfo: PTypeInfo): TAttr; overload; static;
    class function CreateValueOnly(const AValue: Variant): TAttr; overload; static;
    class function CreateValueOnly(const AValue; ATypeInfo: PTypeInfo): TAttr; overload; static;
  end;

  TLogHandler = procedure(Time: TDateTime; Level: TLogLevel;
    const Msg: string; const Attrs: array of TAttr) of object;

  // Объявляем TFileHandler ДО Tslog, так как Tslog использует его в качестве поля
  TFileHandler = class
  private
    FFileName: string;
    FFileStream: TFileStream;
    FCS: TCriticalSection;
    function OpenFile: Boolean;
    procedure CloseFile;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Write(Time: TDateTime; Level: TLogLevel;
      const Msg: string; const Attrs: array of TAttr);
  end;

  // Новый интерфейс для сериализации
  ITypeSerializer = interface
    ['{A3B4C5D6-E7F8-49AA-BBCC-DDEEFF001122}']
    function CanSerialize(TypeInfo: PTypeInfo): Boolean;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string;
  end;

  // Базовый сериализатор
  TBaseSerializer = class(TInterfacedObject, ITypeSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; virtual; abstract;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; virtual; abstract;
  end;

  Tslog = class
  private
    FLevel: TLogLevel;
    FHandler: TLogHandler;
    FCS: TCriticalSection;
    FEnabled: Boolean;
    FFileHandler: TFileHandler;
    FSerializers: TList<ITypeSerializer>;
    FFormatOptions: TFormatOptions;

    class var FDefault: Tslog;

    procedure DefaultHandler(Time: TDateTime; Level: TLogLevel;
      const Msg: string; const Attrs: array of TAttr);

    procedure InitSerializers;
    function FindSerializer(TypeInfo: PTypeInfo): ITypeSerializer;

    // Новые методы сериализации с поддержкой глубины
    function SerializeValue(const Value: TValue; Depth: Integer = 0): string; overload;
    function SerializeValue(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; overload;
    function SerializeRecord(const Value: TValue; TypeInfo: PTypeInfo;
      const Options: TFormatOptions; Depth: Integer): string;
    function SerializeObject(Obj: TObject; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeArray(const Value: TValue; TypeInfo: PTypeInfo;
      const Options: TFormatOptions; Depth: Integer): string;
    function SerializeDynArray(const Value: TValue; TypeInfo: PTypeInfo;
      const Options: TFormatOptions; Depth: Integer): string;
    function SerializeCollection(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeDictionary(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeList(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeStringList(StringList: TStrings; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeInterface(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string;
    function SerializeSet(const Value: TValue; TypeInfo: PTypeInfo;
      const Options: TFormatOptions): string;
    function SerializeEnum(const Value: TValue; TypeInfo: PTypeInfo;
      const Options: TFormatOptions): string;

    // Вспомогательные методы
    function IsCollection(const Value: TValue): Boolean;
    function IsDictionary(const Value: TValue): Boolean;
    function IsList(const Value: TValue): Boolean;
    function IsStringList(const Value: TValue): Boolean;
    function GetIndent(Depth: Integer; const Options: TFormatOptions): string;

  public
    constructor Create(Level: TLogLevel = llInfo);
    destructor Destroy; override;

    // Статические методы
    class procedure Debug(const Msg: string); overload; static;
    class procedure Debug(const Msg: string; const Args: array of const); overload; static;
    class procedure Debug(const Msg: string; const Attrs: array of TAttr); overload; static;

    class procedure Info(const Msg: string); overload; static;
    class procedure Info(const Msg: string; const Args: array of const); overload; static;
    class procedure Info(const Msg: string; const Attrs: array of TAttr); overload; static;

    class procedure Warn(const Msg: string); overload; static;
    class procedure Warn(const Msg: string; const Args: array of const); overload; static;
    class procedure Warn(const Msg: string; const Attrs: array of TAttr); overload; static;

    class procedure Error(const Msg: string); overload; static;
    class procedure Error(const Msg: string; const Args: array of const); overload; static;
    class procedure Error(const Msg: string; const Attrs: array of TAttr); overload; static;

    // Базовые методы
    procedure Log(Level: TLogLevel; const Msg: string); overload;
    procedure Log(Level: TLogLevel; const Msg: string; const Attrs: array of TAttr); overload;

    // Функции создания атрибутов (ключ-значение) - обновленные
    class function Str(const Key, Value: string): TAttr; static;
    class function Int(const Key: string; Value: Int64): TAttr; static;
    class function Bool(const Key: string; Value: Boolean): TAttr; static;
    class function Float(const Key: string; Value: Double): TAttr; static;
    class function Any(const Key: string; const Value: Variant): TAttr; overload; static;
    class function Any(const Key: string; const Value; TypeInfo: Pointer): TAttr; overload; static;
    class function Any<T>(const Key: string; const Value: T): TAttr; overload; static;

    // Функции создания значений (без ключа)
    class function StrValue(const Value: string): TAttr; static;
    class function IntValue(Value: Int64): TAttr; static;
    class function BoolValue(Value: Boolean): TAttr; static;
    class function FloatValue(Value: Double): TAttr; static;
    class function AnyValue(const Value: Variant): TAttr; overload; static;
    class function AnyValue(const Value; TypeInfo: Pointer): TAttr; overload; static;
    class function AnyValue<T>(const Value: T): TAttr; overload; static;

    // Специальные типы
    class function Err(Value: Exception): TAttr; static;
    class function Time(const Key: string; Value: TDateTime): TAttr; static;
    class function Duration(const Key: string; Value: Int64): TAttr; static;
    class function TimeValue(Value: TDateTime): TAttr; static;
    class function DurationValue(Value: Int64): TAttr; static;

    // Расширенные возможности
    class function ToString(Obj: TObject): string; overload; static;
    class function ToString(const Value; TypeInfo: Pointer): string; overload; static;
    class function ToString<T>(const Value: T): string; overload; static;

    // Новая улучшенная сериализация
    function Serialize(const Value: TValue): string; overload;
    function Serialize<T>(const Value: T): string; overload;

    // Утилиты
    class function ArgsToAttrs(const Args: array of const): TArray<TAttr>; static;
    class function FormatAttrs(const Attrs: array of TAttr): string; static;

    // Конфигурация
    procedure SetLevel(Level: TLogLevel);
    procedure SetHandler(Handler: TLogHandler);
    procedure SetFileHandler(const FileName: string);
    procedure RemoveFileHandler;
    procedure Enable;
    procedure Disable;

    // Конфигурация форматирования
    procedure SetFormatOptions(const Options: TFormatOptions);
    function GetFormatOptions: TFormatOptions;

    // Регистрация кастомных сериализаторов
    procedure RegisterSerializer(Serializer: ITypeSerializer);
    procedure UnregisterSerializer(Serializer: ITypeSerializer);

    // Статические методы конфигурации
    class procedure SetDefaultFileHandler(const FileName: string); static;

    class function Default: Tslog; static;
    class destructor Destroy;
  end;

  // Сериализаторы для конкретных типов
  TEnumSerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

  TSetSerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

  TArraySerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

  TRecordSerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

  TClassSerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

  // Обработчик для Debug Output (видно в IDE)
  TDebugOutputHandler = class
  public
    procedure Write(Time: TDateTime; Level: TLogLevel;
      const Msg: string; const Attrs: array of TAttr);
  end;

// Глобальные функции
procedure Debug(const Msg: string); overload;
procedure Debug(const Msg: string; const Args: array of const); overload;
procedure Debug(const Msg: string; const Attrs: array of TAttr); overload;

procedure Info(const Msg: string); overload;
procedure Info(const Msg: string; const Args: array of const); overload;
procedure Info(const Msg: string; const Attrs: array of TAttr); overload;

procedure Warn(const Msg: string); overload;
procedure Warn(const Msg: string; const Args: array of const); overload;
procedure Warn(const Msg: string; const Attrs: array of TAttr); overload;

procedure Error(const Msg: string); overload;
procedure Error(const Msg: string; const Args: array of const); overload;
procedure Error(const Msg: string; const Attrs: array of TAttr); overload;

implementation

var
  GDebugHandler: TDebugOutputHandler;

{ TFormatOptions }

class function TFormatOptions.Default: TFormatOptions;
begin
  Result.MaxDepth := 5;
  Result.MaxElements := 20;
  Result.ShowClassNames := True;
  Result.ShowTypeInfo := False;
  Result.ShowNilValues := True;
  Result.ShowEmptyCollections := True;
  Result.DateTimeFormat := 'yyyy-mm-dd hh:nn:ss.zzz';
  Result.FloatPrecision := 6;
  Result.IndentString := '  ';
end;

{ TAttr }

class function TAttr.Create(const AKey: string; const AValue: Variant): TAttr;
begin
  Result.Key := AKey;
  Result.Value := AValue;
  Result.TypeInfo := nil;
  Result.RawData := nil;
end;

class function TAttr.Create(const AKey: string; const Value;
  ATypeInfo: PTypeInfo): TAttr;
begin
  Result.Key := AKey;
  Result.Value := Null;
  Result.TypeInfo := ATypeInfo;
  Result.RawData := @Value;
end;

class function TAttr.CreateValueOnly(const AValue: Variant): TAttr;
begin
  Result := TAttr.Create('', AValue);
end;

class function TAttr.CreateValueOnly(const Value; ATypeInfo: PTypeInfo): TAttr;
begin
  Result := TAttr.Create('', Value, ATypeInfo);
end;

{ TFileHandler }

function TFileHandler.OpenFile: Boolean;
begin
  Result := False;
  try
    CloseFile;

    if FileExists(FFileName) then
    begin
      FFileStream := TFileStream.Create(FFileName,
        fmOpenWrite or fmShareDenyWrite);
      FFileStream.Seek(0, soFromEnd);
    end
    else
    begin
      FFileStream := TFileStream.Create(FFileName, fmCreate);
    end;

    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
    end;
  end;
end;

procedure TFileHandler.CloseFile;
begin
  FreeAndNil(FFileStream);
end;

constructor TFileHandler.Create(const FileName: string);
begin
  FFileName := FileName;
  FCS := TCriticalSection.Create;

  try
    ForceDirectories(ExtractFilePath(FileName));
  except
    // Игнорируем ошибки создания директории
  end;

  FFileStream := nil;
end;

destructor TFileHandler.Destroy;
begin
  CloseFile;
  FCS.Free;
  inherited;
end;

procedure TFileHandler.Write(Time: TDateTime; Level: TLogLevel;
  const Msg: string; const Attrs: array of TAttr);
var
  LevelStr, AttrStr, LogStr: string;
  Bytes: TBytes;
begin
  FCS.Enter;
  try
    if not Assigned(FFileStream) then
    begin
      if not OpenFile then
        Exit;
    end;

    case Level of
      llDebug: LevelStr := 'DEBUG';
      llInfo:  LevelStr := 'INFO';
      llWarn:  LevelStr := 'WARN';
      llError: LevelStr := 'ERROR';
    end;

    AttrStr := Tslog.FormatAttrs(Attrs);

    if AttrStr <> '' then
      LogStr := Format('%s %-5s %s %s' + sLineBreak,
        [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Time), LevelStr, Msg, AttrStr])
    else
      LogStr := Format('%s %-5s %s' + sLineBreak,
        [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Time), LevelStr, Msg]);

    try
      Bytes := TEncoding.UTF8.GetBytes(LogStr);
      FFileStream.Write(Bytes[0], Length(Bytes));
    except
      on E: Exception do
      begin
        CloseFile;
      end;
    end;
  finally
    FCS.Leave;
  end;
end;

{ TEnumSerializer }

function TEnumSerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  Result := TypeInfo^.Kind = tkEnumeration;
end;

function TEnumSerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
begin
  if Value.TypeInfo = System.TypeInfo(Boolean) then
    Result := BoolToStr(Value.AsBoolean, True)
  else
    Result := GetEnumName(Value.TypeInfo, Value.AsInteger);
end;

{ TSetSerializer }

function TSetSerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  Result := TypeInfo^.Kind = tkSet;
end;

function TSetSerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  IntValue: Integer;
begin
  IntValue := Value.AsInteger;
  Result := System.TypInfo.SetToString(Value.TypeInfo, IntValue, True);
end;

{ TArraySerializer }

function TArraySerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  Result := TypeInfo^.Kind in [tkArray, tkDynArray];
end;

function TArraySerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  TslogInstance: Tslog;
begin
  TslogInstance := Tslog.Create;
  try
    Result := TslogInstance.SerializeArray(Value, Value.TypeInfo, Options, Depth);
  finally
    TslogInstance.Free;
  end;
end;

{ TRecordSerializer }

function TRecordSerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  Result := TypeInfo^.Kind in [tkRecord, tkMRecord];
end;

function TRecordSerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  TslogInstance: Tslog;
begin
  TslogInstance := Tslog.Create;
  try
    Result := TslogInstance.SerializeRecord(Value, Value.TypeInfo, Options, Depth);
  finally
    TslogInstance.Free;
  end;
end;

{ TClassSerializer }

function TClassSerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  Result := TypeInfo^.Kind = tkClass;
end;

function TClassSerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  TslogInstance: Tslog;
begin
  TslogInstance := Tslog.Create;
  try
    Result := TslogInstance.SerializeObject(Value.AsObject, Options, Depth);
  finally
    TslogInstance.Free;
  end;
end;

{ Tslog }

constructor Tslog.Create(Level: TLogLevel);
begin
  FLevel := Level;
  FCS := TCriticalSection.Create;
  FEnabled := True;
  FFileHandler := nil;
  FHandler := DefaultHandler;
  FFormatOptions := TFormatOptions.Default;
  FSerializers := TList<ITypeSerializer>.Create;

  InitSerializers;
end;

destructor Tslog.Destroy;
begin
  if Assigned(FFileHandler) then
    FFileHandler.Free;

  FSerializers.Free;
  FCS.Free;
  inherited;
end;

procedure Tslog.InitSerializers;
begin
  // Регистрируем стандартные сериализаторы
  RegisterSerializer(TEnumSerializer.Create);
  RegisterSerializer(TSetSerializer.Create);
  RegisterSerializer(TArraySerializer.Create);
  RegisterSerializer(TRecordSerializer.Create);
  RegisterSerializer(TClassSerializer.Create);
end;

function Tslog.FindSerializer(TypeInfo: PTypeInfo): ITypeSerializer;
var
  Serializer: ITypeSerializer;
begin
  Result := nil;
  for Serializer in FSerializers do
  begin
    if Serializer.CanSerialize(TypeInfo) then
    begin
      Result := Serializer;
      Exit;
    end;
  end;
end;

procedure Tslog.RegisterSerializer(Serializer: ITypeSerializer);
begin
  FSerializers.Add(Serializer);
end;

procedure Tslog.UnregisterSerializer(Serializer: ITypeSerializer);
begin
  FSerializers.Remove(Serializer);
end;

function Tslog.GetIndent(Depth: Integer; const Options: TFormatOptions): string;
begin
  if Depth <= 0 then
    Result := ''
  else
    Result := StringOfChar(Options.IndentString[1], Depth * Length(Options.IndentString));
end;

function Tslog.SerializeValue(const Value: TValue; Depth: Integer): string;
begin
  Result := SerializeValue(Value, FFormatOptions, Depth);
end;

function Tslog.SerializeValue(const Value: TValue; const Options: TFormatOptions;
  Depth: Integer): string;
var
  Serializer: ITypeSerializer;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  if Value.IsEmpty then
  begin
    Result := 'nil';
    Exit;
  end;

  // Ищем специализированный сериализатор
  Serializer := FindSerializer(Value.TypeInfo);
  if Assigned(Serializer) then
  begin
    try
      Result := Serializer.Serialize(Value, Options, Depth);
      Exit;
    except
      // Если сериализатор сломался, падаем назад на базовый
    end;
  end;

  // Базовая сериализация по типу
  case Value.TypeInfo^.Kind of
    tkInteger, tkInt64:
      Result := Value.ToString;
    tkChar, tkWChar:
      Result := QuotedStr(Value.AsString);
    tkString, tkLString, tkWString, tkUString:
      begin
        Result := Value.AsString;
        if (Pos(' ', Result) > 0) or (Result = '') then
          Result := QuotedStr(Result);
      end;
    tkFloat:
      begin
        if Value.TypeInfo = System.TypeInfo(TDateTime) then
          Result := FormatDateTime(Options.DateTimeFormat, Value.AsExtended)
        else if Value.TypeInfo = System.TypeInfo(TDate) then
          Result := FormatDateTime('yyyy-mm-dd', Value.AsExtended)
        else if Value.TypeInfo = System.TypeInfo(TTime) then
          Result := FormatDateTime('hh:nn:ss.zzz', Value.AsExtended)
        else
          Result := FloatToStrF(Value.AsExtended, ffGeneral,
            Options.FloatPrecision, 0);
      end;
    tkVariant:
      Result := VarToStr(Value.AsVariant);
    tkEnumeration:
      Result := SerializeEnum(Value, Value.TypeInfo, Options);
    tkSet:
      Result := SerializeSet(Value, Value.TypeInfo, Options);
    tkRecord, tkMRecord:
      Result := SerializeRecord(Value, Value.TypeInfo, Options, Depth);
    tkClass:
      Result := SerializeObject(Value.AsObject, Options, Depth);
    tkArray:
      Result := SerializeArray(Value, Value.TypeInfo, Options, Depth);
    tkDynArray:
      Result := SerializeDynArray(Value, Value.TypeInfo, Options, Depth);
    tkInterface:
      Result := SerializeInterface(Value, Options, Depth);
    tkPointer:
      Result := Format('0x%p', [Pointer(Value.AsPointer)]);
    tkClassRef:
      Result := Value.AsClass.ClassName + ' (class)';
    tkProcedure:
      Result := 'procedure';
    tkMethod:
      Result := 'method';
  else
    Result := 'unknown';
  end;
end;

function Tslog.SerializeEnum(const Value: TValue; TypeInfo: PTypeInfo;
  const Options: TFormatOptions): string;
begin
  if TypeInfo = System.TypeInfo(Boolean) then
    Result := BoolToStr(Value.AsBoolean, True)
  else
    Result := GetEnumName(TypeInfo, Value.AsInteger);
end;

function Tslog.SerializeSet(const Value: TValue; TypeInfo: PTypeInfo;
  const Options: TFormatOptions): string;
var
  IntValue: Integer;
begin
  IntValue := Value.AsInteger;
  Result := System.TypInfo.SetToString(TypeInfo, IntValue, True);
end;

function Tslog.SerializeRecord(const Value: TValue; TypeInfo: PTypeInfo;
  const Options: TFormatOptions; Depth: Integer): string;
var
  Context: TRttiContext;
  RttiType: TRttiRecordType;
  Field: TRttiField;
  FieldValue: TValue;
  First: Boolean;
  Indent: string;
  NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(TypeInfo).AsRecord;
    if RttiType = nil then
      Exit('Record{}');

    Indent := GetIndent(Depth, Options);
    NextIndent := GetIndent(Depth + 1, Options);

    Result := 'Record{' + sLineBreak;
    First := True;

    for Field in RttiType.GetFields do
    begin
      if Field.Visibility >= mvPublic then
      begin
        try
          FieldValue := Field.GetValue(Value.GetReferenceToRawData);
          if not FieldValue.IsEmpty then
          begin
            if not First then
              Result := Result + ',' + sLineBreak;

            Result := Result + NextIndent + Field.Name + ' = ' +
              SerializeValue(FieldValue, Options, Depth + 1);
            First := False;
          end;
        except
          // Игнорируем поля, которые нельзя прочитать
        end;
      end;
    end;

    Result := Result + sLineBreak + Indent + '}';
  finally
    Context.Free;
  end;
end;

function Tslog.SerializeObject(Obj: TObject; const Options: TFormatOptions;
  Depth: Integer): string;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Field: TRttiField;
  Value: TValue;
  First: Boolean;
  Indent: string;
  NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  if Obj = nil then
  begin
    Result := 'nil';
    Exit;
  end;

  // Проверяем специальные типы
  if IsCollection(TValue.From(Obj)) then
    Result := SerializeCollection(TValue.From(Obj), Options, Depth)
  else if IsDictionary(TValue.From(Obj)) then
    Result := SerializeDictionary(TValue.From(Obj), Options, Depth)
  else if IsList(TValue.From(Obj)) then
    Result := SerializeList(TValue.From(Obj), Options, Depth)
  else if IsStringList(TValue.From(Obj)) then
    Result := SerializeStringList(TStrings(Obj), Options, Depth)
  else
  begin
    // Общий случай: используем RTTI
    Context := TRttiContext.Create;
    try
      RttiType := Context.GetType(Obj.ClassType);
      if RttiType = nil then
        Exit(Obj.ClassName + '{}');

      Indent := GetIndent(Depth, Options);
      NextIndent := GetIndent(Depth + 1, Options);

      if Options.ShowClassNames then
        Result := Obj.ClassName + '{' + sLineBreak
      else
        Result := '{' + sLineBreak;

      First := True;

      // Обрабатываем свойства
      for Prop in RttiType.GetProperties do
      begin
        if Prop.IsReadable and (Prop.Visibility >= mvPublic) then
        begin
          try
            Value := Prop.GetValue(Obj);
            if not Value.IsEmpty or Options.ShowNilValues then
            begin
              if not First then
                Result := Result + ',' + sLineBreak;

              Result := Result + NextIndent + Prop.Name + ' = ' +
                SerializeValue(Value, Options, Depth + 1);
              First := False;
            end;
          except
            // Игнорируем свойства, которые нельзя прочитать
          end;
        end;
      end;

      // Обрабатываем поля
      for Field in RttiType.GetFields do
      begin
        if Field.Visibility >= mvPublic then
        begin
          try
            Value := Field.GetValue(Obj);
            if not Value.IsEmpty or Options.ShowNilValues then
            begin
              if not First then
                Result := Result + ',' + sLineBreak;

              Result := Result + NextIndent + Field.Name + ' = ' +
                SerializeValue(Value, Options, Depth + 1);
              First := False;
            end;
          except
            // Игнорируем поля, которые нельзя прочитать
          end;
        end;
      end;

      Result := Result + sLineBreak + Indent + '}';
    finally
      Context.Free;
    end;
  end;
end;

function Tslog.SerializeArray(const Value: TValue; TypeInfo: PTypeInfo;
  const Options: TFormatOptions; Depth: Integer): string;
var
  Len: Integer;
  i: Integer;
  Element: TValue;
  First: Boolean;
  Indent: string;
  NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  Len := Value.GetArrayLength;

  if Len = 0 then
  begin
    Result := '[]';
    Exit;
  end;

  Indent := GetIndent(Depth, Options);
  NextIndent := GetIndent(Depth + 1, Options);

  Result := '[' + sLineBreak;
  First := True;

  for i := 0 to Min(Len - 1, Options.MaxElements - 1) do
  begin
    Element := Value.GetArrayElement(i);

    if not First then
      Result := Result + ',' + sLineBreak;

    Result := Result + NextIndent + SerializeValue(Element, Options, Depth + 1);
    First := False;
  end;

  if Len > Options.MaxElements then
    Result := Result + ',' + sLineBreak + NextIndent + '... (+' +
      IntToStr(Len - Options.MaxElements) + ' more)';

  Result := Result + sLineBreak + Indent + ']';
end;

function Tslog.SerializeDynArray(const Value: TValue; TypeInfo: PTypeInfo;
  const Options: TFormatOptions; Depth: Integer): string;
begin
  Result := SerializeArray(Value, TypeInfo, Options, Depth);
end;

function Tslog.IsCollection(const Value: TValue): Boolean;
begin
  Result := False;
  if Value.TypeInfo^.Kind = tkClass then
  begin
    Result := Value.AsObject.InheritsFrom(TCollection);
  end;
end;

function Tslog.IsDictionary(const Value: TValue): Boolean;
begin
  Result := False;
  if Value.TypeInfo^.Kind = tkClass then
  begin
    // Проверяем на TDictionary<,> или TObjectDictionary<,>
    Result := Pos('TDictionary<', Value.AsObject.ClassName) > 0;
    if not Result then
      Result := Pos('TObjectDictionary<', Value.AsObject.ClassName) > 0;
  end;
end;

function Tslog.IsList(const Value: TValue): Boolean;
begin
  Result := False;
  if Value.TypeInfo^.Kind = tkClass then
  begin
    // Проверяем на TList<> или TObjectList<>
    Result := Pos('TList<', Value.AsObject.ClassName) > 0;
    if not Result then
      Result := Pos('TObjectList<', Value.AsObject.ClassName) > 0;
  end;
end;

function Tslog.IsStringList(const Value: TValue): Boolean;
begin
  Result := False;
  if Value.TypeInfo^.Kind = tkClass then
  begin
    Result := Value.AsObject.InheritsFrom(TStrings);
  end;
end;

function Tslog.SerializeCollection(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  Collection: TCollection;
  i: Integer;
  First: Boolean;
  Indent: string;
  NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  Collection := TCollection(Value.AsObject);

  if Collection.Count = 0 then
  begin
    Result := 'Collection[]';
    Exit;
  end;

  Indent := GetIndent(Depth, Options);
  NextIndent := GetIndent(Depth + 1, Options);

  Result := 'Collection[' + sLineBreak;
  First := True;

  for i := 0 to Min(Collection.Count - 1, Options.MaxElements - 1) do
  begin
    if not First then
      Result := Result + ',' + sLineBreak;

    Result := Result + NextIndent + 'Item[' + IntToStr(i) + '] = ' +
      SerializeObject(Collection.Items[i], Options, Depth + 2);
    First := False;
  end;

  if Collection.Count > Options.MaxElements then
    Result := Result + ',' + sLineBreak + NextIndent + '... (+' +
      IntToStr(Collection.Count - Options.MaxElements) + ' more)';

  Result := Result + sLineBreak + Indent + ']';
end;

function Tslog.SerializeDictionary(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  Dict: TObject;
  Context: TRttiContext;
  RttiType: TRttiType;
  CountProp: TRttiProperty;
  GetEnumeratorMethod: TRttiMethod;
  Enumerator, Pair: TValue;
  MoveNextMethod, CurrentProp: TRttiMethod;
  KeyField, ValueField: TRttiField;
  i, Count: Integer;
  First: Boolean;
  Indent, NextIndent: string;
begin
  Result := 'Dictionary{...}'; // Упрощенная реализация
  Exit; // Полная реализация требует больше кода

  // Это сложная задача, требующая рефлексии для обхода generic-типов
  // Здесь представлен упрощенный вариант
end;

function Tslog.SerializeList(const Value: TValue; const Options: TFormatOptions;
  Depth: Integer): string;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  CountProp: TRttiProperty;
  ItemsProp: TRttiProperty;
  ItemsValue: TValue;
  i, Count: Integer;
  Element: TValue;
  First: Boolean;
  Indent, NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(Value.AsObject.ClassType);

    CountProp := RttiType.GetProperty('Count');
    ItemsProp := RttiType.GetProperty('Items');

    if Assigned(CountProp) and Assigned(ItemsProp) then
    begin
      Count := CountProp.GetValue(Value.AsObject).AsInteger;

      if Count = 0 then
      begin
        Result := 'List[]';
        Exit;
      end;

      Indent := GetIndent(Depth, Options);
      NextIndent := GetIndent(Depth + 1, Options);

      Result := 'List[' + sLineBreak;
      First := True;

      for i := 0 to Min(Count - 1, Options.MaxElements - 1) do
      begin
        Element := ItemsProp.GetValue(Value.AsObject, [i]);

        if not First then
          Result := Result + ',' + sLineBreak;

        Result := Result + NextIndent + '[' + IntToStr(i) + '] = ' +
          SerializeValue(Element, Options, Depth + 1);
        First := False;
      end;

      if Count > Options.MaxElements then
        Result := Result + ',' + sLineBreak + NextIndent + '... (+' +
          IntToStr(Count - Options.MaxElements) + ' more)';

      Result := Result + sLineBreak + Indent + ']';
    end
    else
      Result := Value.AsObject.ClassName + '{...}';
  finally
    Context.Free;
  end;
end;

function Tslog.SerializeStringList(StringList: TStrings;
  const Options: TFormatOptions; Depth: Integer): string;
var
  i: Integer;
  First: Boolean;
  Indent, NextIndent: string;
begin
  if Depth > Options.MaxDepth then
  begin
    Result := '...';
    Exit;
  end;

  if StringList.Count = 0 then
  begin
    Result := 'StringList[]';
    Exit;
  end;

  Indent := GetIndent(Depth, Options);
  NextIndent := GetIndent(Depth + 1, Options);

  Result := 'StringList[' + sLineBreak;
  First := True;

  for i := 0 to Min(StringList.Count - 1, Options.MaxElements - 1) do
  begin
    if not First then
      Result := Result + ',' + sLineBreak;

    Result := Result + NextIndent + '[' + IntToStr(i) + '] = ' +
      QuotedStr(StringList[i]);
    First := False;
  end;

  if StringList.Count > Options.MaxElements then
    Result := Result + ',' + sLineBreak + NextIndent + '... (+' +
      IntToStr(StringList.Count - Options.MaxElements) + ' more)';

  Result := Result + sLineBreak + Indent + ']';
end;

function Tslog.SerializeInterface(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
begin
  Result := 'Interface';
end;

function Tslog.Serialize(const Value: TValue): string;
begin
  Result := SerializeValue(Value, FFormatOptions, 0);
end;

function Tslog.Serialize<T>(const Value: T): string;
begin
  Result := SerializeValue(TValue.From<T>(Value), FFormatOptions, 0);
end;

class function Tslog.Default: Tslog;
begin
  if not Assigned(FDefault) then
    FDefault := Tslog.Create;
  Result := FDefault;
end;

class destructor Tslog.Destroy;
begin
  FreeAndNil(FDefault);
end;

function VarRecToTValue(const Arg: TVarRec): TValue;
begin
  case Arg.VType of
    vtInteger:       Result := Arg.VInteger;
    vtBoolean:       Result := Arg.VBoolean;
    vtChar:          Result := string(Arg.VChar);
    vtExtended:      Result := Arg.VExtended^;
    vtString:        Result := string(Arg.VString^);
    vtPChar:         Result := string(Arg.VPChar);
    vtAnsiString:    Result := string(PAnsiString(Arg.VAnsiString)^);
    vtWideString:    Result := WideString(PWideString(Arg.VWideString)^);
    vtUnicodeString: Result := string(Arg.VUnicodeString);
    vtInt64:         Result := PInt64(Arg.VInt64)^;
    vtVariant:       Result := TValue.FromVariant(PVariant(Arg.VVariant)^);
    vtObject:        Result := Arg.VObject;
    vtClass:         Result := Arg.VClass;
  else
    Result := TValue.Empty;
  end;
end;

class function Tslog.ArgsToAttrs(const Args: array of const): TArray<TAttr>;
var
  I: Integer;
  Value: TValue;
begin
  if Length(Args) = 0 then
    Exit(nil);

  SetLength(Result, Length(Args));
  for I := 0 to High(Args) do
  begin
    Value := VarRecToTValue(Args[I]);
    if Value.IsEmpty then
      Result[I] := TAttr.Create('key' + IntToStr(I + 1), '?')
    else
      Result[I] := TAttr.Create('key' + IntToStr(I + 1),
        VarRecToTValue(Args[I]).AsVariant);
  end;
end;

class function Tslog.FormatAttrs(const Attrs: array of TAttr): string;
var
  I: Integer;
  Attr: TAttr;
  ValueStr: string;
begin
  Result := '';

  for I := 0 to High(Attrs) do
  begin
    Attr := Attrs[I];

    if Attr.TypeInfo <> nil then
    begin
      // Используем новую сериализацию
      var Instance := Tslog.Create;
      try
        var Value := TValue.From(Attr.RawData, Attr.TypeInfo);
        ValueStr := Instance.SerializeValue(Value, Instance.FFormatOptions, 0);
      finally
        Instance.Free;
      end;
    end
    else
      ValueStr := VarToStr(Attr.Value);

    if (Pos(' ', ValueStr) > 0) or (Pos('=', ValueStr) > 0) or
       (Pos('[', ValueStr) > 0) or (Pos(']', ValueStr) > 0) or
       (ValueStr = '') then
      ValueStr := '"' + ValueStr + '"';

    if Result <> '' then
      Result := Result + ' ';

    if Attr.Key = '' then
      Result := Result + Format('value%d=%s', [I + 1, ValueStr])
    else
      Result := Result + Format('%s=%s', [Attr.Key, ValueStr]);
  end;
end;

procedure Tslog.DefaultHandler(Time: TDateTime; Level: TLogLevel;
  const Msg: string; const Attrs: array of TAttr);
begin
  if Assigned(GDebugHandler) then
    GDebugHandler.Write(Time, Level, Msg, Attrs);
end;

procedure Tslog.Log(Level: TLogLevel; const Msg: string);
begin
  Log(Level, Msg, []);
end;

procedure Tslog.Log(Level: TLogLevel; const Msg: string; const Attrs: array of TAttr);
begin
  if not FEnabled or (Level < FLevel) then
    Exit;

  FCS.Enter;
  try
    if Assigned(FHandler) then
      FHandler(Now, Level, Msg, Attrs);
  finally
    FCS.Leave;
  end;
end;

// Статические методы логирования
class procedure Tslog.Debug(const Msg: string);
begin
  Default.Log(llDebug, Msg);
end;

class procedure Tslog.Debug(const Msg: string; const Args: array of const);
begin
  Default.Log(llDebug, Msg, ArgsToAttrs(Args));
end;

class procedure Tslog.Debug(const Msg: string; const Attrs: array of TAttr);
begin
  Default.Log(llDebug, Msg, Attrs);
end;

class procedure Tslog.Info(const Msg: string);
begin
  Default.Log(llInfo, Msg);
end;

class procedure Tslog.Info(const Msg: string; const Args: array of const);
begin
  Default.Log(llInfo, Msg, ArgsToAttrs(Args));
end;

class procedure Tslog.Info(const Msg: string; const Attrs: array of TAttr);
begin
  Default.Log(llInfo, Msg, Attrs);
end;

class procedure Tslog.Warn(const Msg: string);
begin
  Default.Log(llWarn, Msg);
end;

class procedure Tslog.Warn(const Msg: string; const Args: array of const);
begin
  Default.Log(llWarn, Msg, ArgsToAttrs(Args));
end;

class procedure Tslog.Warn(const Msg: string; const Attrs: array of TAttr);
begin
  Default.Log(llWarn, Msg, Attrs);
end;

class procedure Tslog.Error(const Msg: string);
begin
  Default.Log(llError, Msg);
end;

class procedure Tslog.Error(const Msg: string; const Args: array of const);
begin
  Default.Log(llError, Msg, ArgsToAttrs(Args));
end;

class procedure Tslog.Error(const Msg: string; const Attrs: array of TAttr);
begin
  Default.Log(llError, Msg, Attrs);
end;

// Функции создания атрибутов
class function Tslog.Str(const Key, Value: string): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Int(const Key: string; Value: Int64): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Bool(const Key: string; Value: Boolean): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Float(const Key: string; Value: Double): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Any(const Key: string; const Value: Variant): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Any(const Key: string; const Value; TypeInfo: Pointer): TAttr;
begin
  Result := TAttr.Create(Key, Value, TypeInfo);
end;

class function Tslog.Any<T>(const Key: string; const Value: T): TAttr;
begin
  Result := TAttr.Create(Key, Value, System.TypeInfo(T));
end;

class function Tslog.Err(Value: Exception): TAttr;
begin
  if Assigned(Value) then
    Result := TAttr.Create('error', Value.Message)
  else
    Result := TAttr.Create('error', 'nil');
end;

class function Tslog.Time(const Key: string; Value: TDateTime): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

class function Tslog.Duration(const Key: string; Value: Int64): TAttr;
begin
  Result := TAttr.Create(Key, Value);
end;

// Функции создания значений
class function Tslog.StrValue(const Value: string): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.IntValue(Value: Int64): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.BoolValue(Value: Boolean): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.FloatValue(Value: Double): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.AnyValue(const Value: Variant): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.AnyValue(const Value; TypeInfo: Pointer): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value, TypeInfo);
end;

class function Tslog.AnyValue<T>(const Value: T): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value, System.TypeInfo(T));
end;

class function Tslog.TimeValue(Value: TDateTime): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

class function Tslog.DurationValue(Value: Int64): TAttr;
begin
  Result := TAttr.CreateValueOnly(Value);
end;

// Конфигурация
procedure Tslog.SetLevel(Level: TLogLevel);
begin
  FLevel := Level;
end;

procedure Tslog.SetHandler(Handler: TLogHandler);
begin
  FCS.Enter;
  try
    if Assigned(FFileHandler) then
      FreeAndNil(FFileHandler);

    FHandler := Handler;
  finally
    FCS.Leave;
  end;
end;

procedure Tslog.SetFileHandler(const FileName: string);
begin
  FCS.Enter;
  try
    if Assigned(FFileHandler) then
      FreeAndNil(FFileHandler);

    FFileHandler := TFileHandler.Create(FileName);
    FHandler := FFileHandler.Write;
  finally
    FCS.Leave;
  end;
end;

procedure Tslog.RemoveFileHandler;
begin
  FCS.Enter;
  try
    if Assigned(FFileHandler) then
      FreeAndNil(FFileHandler);

    FHandler := DefaultHandler;
  finally
    FCS.Leave;
  end;
end;

procedure Tslog.SetFormatOptions(const Options: TFormatOptions);
begin
  FFormatOptions := Options;
end;

function Tslog.GetFormatOptions: TFormatOptions;
begin
  Result := FFormatOptions;
end;

class procedure Tslog.SetDefaultFileHandler(const FileName: string);
begin
  Default.SetFileHandler(FileName);
end;

procedure Tslog.Enable;
begin
  FEnabled := True;
end;

procedure Tslog.Disable;
begin
  FEnabled := False;
end;

class function Tslog.ToString(Obj: TObject): string;
var
  Instance: Tslog;
begin
  Instance := Tslog.Create;
  try
    Result := Instance.SerializeObject(Obj, Instance.FFormatOptions, 0);
  finally
    Instance.Free;
  end;
end;

class function Tslog.ToString(const Value; TypeInfo: Pointer): string;
var
  Instance: Tslog;
begin
  Instance := Tslog.Create;
  try
    var V := TValue.From(@Value, TypeInfo);
    Result := Instance.SerializeValue(V, Instance.FFormatOptions, 0);
  finally
    Instance.Free;
  end;
end;

class function Tslog.ToString<T>(const Value: T): string;
var
  Instance: Tslog;
begin
  Instance := Tslog.Create;
  try
    Result := Instance.Serialize<T>(Value);
  finally
    Instance.Free;
  end;
end;

{ TDebugOutputHandler }

procedure TDebugOutputHandler.Write(Time: TDateTime; Level: TLogLevel;
  const Msg: string; const Attrs: array of TAttr);
var
  LevelStr, AttrStr, OutputStr: string;
begin
  case Level of
    llDebug: LevelStr := 'DBG';
    llInfo:  LevelStr := 'INF';
    llWarn:  LevelStr := 'WRN';
    llError: LevelStr := 'ERR';
  end;

  AttrStr := Tslog.FormatAttrs(Attrs);

  if AttrStr <> '' then
    OutputStr := Format('%s %s %s %s',
      [FormatDateTime('hh:nn:ss.zzz', Time), LevelStr, Msg, AttrStr])
  else
    OutputStr := Format('%s %s %s',
      [FormatDateTime('hh:nn:ss.zzz', Time), LevelStr, Msg]);

  OutputDebugString(PChar(OutputStr));
end;

{ Глобальные функции }

procedure Debug(const Msg: string);
begin
  Tslog.Debug(Msg);
end;

procedure Debug(const Msg: string; const Args: array of const);
begin
  Tslog.Debug(Msg, Args);
end;

procedure Debug(const Msg: string; const Attrs: array of TAttr);
begin
  Tslog.Debug(Msg, Attrs);
end;

procedure Info(const Msg: string);
begin
  Tslog.Info(Msg);
end;

procedure Info(const Msg: string; const Args: array of const);
begin
  Tslog.Info(Msg, Args);
end;

procedure Info(const Msg: string; const Attrs: array of TAttr);
begin
  Tslog.Info(Msg, Attrs);
end;

procedure Warn(const Msg: string);
begin
  Tslog.Warn(Msg);
end;

procedure Warn(const Msg: string; const Args: array of const);
begin
  Tslog.Warn(Msg, Args);
end;

procedure Warn(const Msg: string; const Attrs: array of TAttr);
begin
  Tslog.Warn(Msg, Attrs);
end;

procedure Error(const Msg: string);
begin
  Tslog.Error(Msg);
end;

procedure Error(const Msg: string; const Args: array of const);
begin
  Tslog.Error(Msg, Args);
end;

procedure Error(const Msg: string; const Attrs: array of TAttr);
begin
  Tslog.Error(Msg, Attrs);
end;

initialization
  GDebugHandler := TDebugOutputHandler.Create;

finalization
  FreeAndNil(GDebugHandler);

end.
