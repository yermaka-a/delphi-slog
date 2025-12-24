# Slog for Delphi

Библиотека структурированного логирования для Delphi, вдохновленная библиотекой slog для Go, с поддержкой атрибутов и расширенной сериализацией объектов.

## Основные возможности

- **Структурированное логирование** с поддержкой атрибутов (ключ-значение)
- **4 уровня логирования**: Debug, Info, Warn, Error
- **Расширенная сериализация** объектов, записей, массивов, коллекций и других типов данных
- **Потокобезопасность** - готово к использованию в многопоточных приложениях
- **Несколько обработчиков**: вывод в Debug Output и запись в файл
- **Гибкая конфигурация** форматирования и сериализации
- **Поддержка пользовательских сериализаторов**

## Установка

Добавьте файл `slog.pas` в ваш проект Delphi (версия XE2 или выше).

## Быстрый старт

### Простое использование

```delphi
uses slog;

begin
  // Базовое логирование
  Debug('Отладочное сообщение');
  Info('Информационное сообщение');
  Warn('Предупреждение');
  Error('Ошибка');

  // Логирование с форматированием
  Info('Пользователь %s вошел в систему', ['Иван']);
  
  // Логирование с атрибутами
  Info('Запрос выполнен', [
    slog.Str('method', 'GET'),
    slog.Int('status', 200),
    slog.Float('duration_ms', 145.6)
  ]);
end;
```

### Использование атрибутов

```delphi
// Строки
slog.Str('username', 'john_doe');
slog.StrValue('значение без ключа');

// Числа
slog.Int('user_id', 12345);
slog.IntValue(42);

// Булевы значения
slog.Bool('active', True);
slog.BoolValue(False);

// Даты/время
slog.Time('start_time', Now);
slog.TimeValue(Now);

// Произвольные типы
slog.Any('object', SomeObject);
slog.Any<TMyRecord>('record', MyRecord);

// Исключения
try
  // какой-то код
except
  on E: Exception do
    Error('Ошибка выполнения', [slog.Err(E)]);
end;
```

## Расширенные примеры

### Логирование объектов

```delphi
type
  TUser = class
  private
    FName: string;
    FAge: Integer;
    FActive: Boolean;
  public
    property Name: string read FName write FName;
    property Age: Integer read FAge write FAge;
    property Active: Boolean read FActive write FActive;
  end;

var
  User: TUser;
begin
  User := TUser.Create;
  try
    User.Name := 'Иван';
    User.Age := 30;
    User.Active := True;
    
    // Автоматическая сериализация объекта
    Debug('Данные пользователя', [slog.Any('user', User)]);
    
    // Или через специальный метод
    Debug('Пользователь', [slog.Any<TUser>('user', User)]);
  finally
    User.Free;
  end;
end;
```

### Логирование коллекций и массивов

```delphi
var
  List: TList<Integer>;
  Dict: TDictionary<string, Integer>;
  Arr: array of string;
begin
  // Список
  List := TList<Integer>.Create;
  try
    List.Add(1);
    List.Add(2);
    List.Add(3);
    Debug('Список чисел', [slog.Any('numbers', List)]);
  finally
    List.Free;
  end;

  // Динамический массив
  SetLength(Arr, 3);
  Arr[0] := 'один';
  Arr[1] := 'два';
  Arr[2] := 'три';
  Debug('Массив строк', [slog.Any('array', Arr)]);
end;
```

### Конфигурация

```delphi
// Настройка уровня логирования
slog.Default.SetLevel(llDebug); // Все сообщения
// slog.Default.SetLevel(llInfo);  // Только Info, Warn, Error
// slog.Default.SetLevel(llError); // Только Error

// Запись в файл
slog.SetDefaultFileHandler('C:\Logs\myapp.log');

// Или настройка собственного экземпляра
var
  Logger: Tslog;
begin
  Logger := Tslog.Create(llDebug);
  try
    Logger.SetFileHandler('app.log');
    
    // Настройка форматирования
    var Options := TFormatOptions.Default;
    Options.MaxDepth := 3;
    Options.DateTimeFormat := 'dd.mm.yyyy hh:nn:ss';
    Options.IndentString := '    ';
    Logger.SetFormatOptions(Options);
    
    Logger.Info('Сообщение с настраиваемым логгером');
  finally
    Logger.Free;
  end;
end;
```

### Пользовательский сериализатор

```delphi
type
  TMyObjectSerializer = class(TBaseSerializer)
  public
    function CanSerialize(TypeInfo: PTypeInfo): Boolean; override;
    function Serialize(const Value: TValue; const Options: TFormatOptions;
      Depth: Integer): string; override;
  end;

function TMyObjectSerializer.CanSerialize(TypeInfo: PTypeInfo): Boolean;
begin
  // Сериализуем только наш специальный тип
  Result := TypeInfo = TypeInfo(TMySpecialObject);
end;

function TMyObjectSerializer.Serialize(const Value: TValue;
  const Options: TFormatOptions; Depth: Integer): string;
var
  Obj: TMySpecialObject;
begin
  Obj := TMySpecialObject(Value.AsObject);
  Result := Format('MySpecialObject{ID=%d, Name=%s}', [Obj.ID, Obj.Name]);
end;

// Регистрация сериализатора
slog.Default.RegisterSerializer(TMyObjectSerializer.Create);
```

## API Reference

### Уровни логирования

- `llDebug` - Отладочные сообщения
- `llInfo` - Информационные сообщения
- `llWarn` - Предупреждения
- `llError` - Ошибки

### Основные методы

#### Статические методы (через Default)
```delphi
class procedure Debug(const Msg: string); overload;
class procedure Debug(const Msg: string; const Args: array of const); overload;
class procedure Debug(const Msg: string; const Attrs: array of TAttr); overload;

class procedure Info(const Msg: string); overload;
class procedure Info(const Msg: string; const Args: array of const); overload;
class procedure Info(const Msg: string; const Attrs: array of TAttr); overload;

class procedure Warn(const Msg: string); overload;
class procedure Warn(const Msg: string; const Args: array of const); overload;
class procedure Warn(const Msg: string; const Attrs: array of TAttr); overload;

class procedure Error(const Msg: string); overload;
class procedure Error(const Msg: string; const Args: array of const); overload;
class procedure Error(const Msg: string; const Attrs: array of TAttr); overload;
```

#### Методы создания атрибутов
```delphi
class function Str(const Key, Value: string): TAttr;
class function Int(const Key: string; Value: Int64): TAttr;
class function Bool(const Key: string; Value: Boolean): TAttr;
class function Float(const Key: string; Value: Double): TAttr;
class function Any(const Key: string; const Value: Variant): TAttr; overload;
class function Any<T>(const Key: string; const Value: T): TAttr; overload;
class function Err(Value: Exception): TAttr;
```

#### Утилиты
```delphi
class function ToString(Obj: TObject): string; overload;
class function ToString<T>(const Value: T): string; overload;
```

### Конфигурация

```delphi
// Управление уровнем логирования
procedure SetLevel(Level: TLogLevel);

// Обработчики
procedure SetHandler(Handler: TLogHandler);
procedure SetFileHandler(const FileName: string);
procedure RemoveFileHandler;
class procedure SetDefaultFileHandler(const FileName: string); static;

// Форматирование
procedure SetFormatOptions(const Options: TFormatOptions);
function GetFormatOptions: TFormatOptions;

// Сериализаторы
procedure RegisterSerializer(Serializer: ITypeSerializer);
procedure UnregisterSerializer(Serializer: ITypeSerializer);

// Включение/отключение
procedure Enable;
procedure Disable;
```

## Формат вывода

По умолчанию логи имеют следующий формат:
```
2024-01-15 14:30:25.123 INFO  Пользователь вошел username="john" user_id=123 active=true
```

При записи в файл добавляется перевод строки.

## Настройка форматирования

```delphi
var
  Options: TFormatOptions;
begin
  Options := TFormatOptions.Default;
  Options.MaxDepth := 3;              // Максимальная глубина сериализации
  Options.MaxElements := 10;          // Максимальное количество элементов в массиве/коллекции
  Options.ShowClassNames := True;     // Показывать имена классов
  Options.DateTimeFormat := 'hh:nn:ss.zzz'; // Формат даты/времени
  Options.FloatPrecision := 2;        // Точность для чисел с плавающей точкой
  Options.IndentString := '  ';       // Строка отступа
  
  slog.Default.SetFormatOptions(Options);
end;
```

## Производительность

- Используется пул критических секций для минимизации блокировок
- Сериализация выполняется только при необходимости
- Поддержка ограничения глубины и количества элементов для больших структур

## Ограничения

- Требуется Delphi XE2 или выше для поддержки расширенного RTTI
- Для сериализации сложных generic-коллекций может потребоваться регистрация специальных сериализаторов
- В текущей реализации упрощенная сериализация словарей (требует доработки для сложных случаев)
