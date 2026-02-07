#ifndef BACKEND_CALCULATOR_H
#define BACKEND_CALCULATOR_H

namespace backend {

class Calculator {
public:
    Calculator();
    ~Calculator();
    
    int add(int a, int b) const;
    int subtract(int a, int b) const;
    int multiply(int a, int b) const;
    int divide(int a, int b) const;
};

}  // namespace backend

#endif  // BACKEND_CALCULATOR_H
