# Paper: Debugging Support for Reactive Programming

> When software engineers look at the source code of an existing application, they want to understand how the program was implemented technically. They do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g., during onboarding of a new team member) or, more often, because someone reported an unexpected application behavior (e.g., the program crashed). Inspecting source code at runtime is commonly known as "debugging". Layman et al. formalized an iterative process model (see Figure 1) by dividing the broader task of debugging into three steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. They then (ii) instrument the program using appropriate techniques to prove their hypothesis. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

## Publishing State

This paper was submitted to the review committee of the ACM SIGSOFT International Symposium on Software Testing and Analysis, 18-22 July, 2022. It got rejected in the process.

## Build in Docker Container

```shell
docker run -it --rm -v `pwd`:/data ghcr.io/swissmanu/pandoc make
```

## Related Git Repositories

- https://github.com/swissmanu/rxjs-debugging-for-vscode
- https://github.com/swissmanu/mse-pa1-experiment
- https://github.com/swissmanu/mse-pa2-usability-test
- https://github.com/swissmanu/mse-pa2-spike-vscode
