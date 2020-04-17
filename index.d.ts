declare module "react-native-http-bridge" {

  export interface Request {
    requestId: number;
    url: string;
    type: "GET" | "POST" | "PUT" | "DELETE";
    postData: any;
    remoteAddess: string;
  }

  export default class HttpBridge {
    static stop: (onSop?: () => void) => void;
    static start: (port: number, name: string, handler: (req: Request) => void, onStart?: () => void) => void;
    static respond: (requestId: number, status: number, contentType: "application/json", data: string) => void;
  }
}

declare namespace gz {
  type Optional<T> = T | undefined;
  type VoidFunc = () => void;
}
