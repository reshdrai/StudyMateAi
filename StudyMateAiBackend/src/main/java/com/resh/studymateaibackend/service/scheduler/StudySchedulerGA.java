package com.resh.studymateaibackend.service.scheduler;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Genetic Algorithm for dynamic study scheduling.
 *
 * Each Chromosome = a full week/multi-day study plan
 * Each Gene = one study task assigned to a specific day + time slot
 *
 * Fitness criteria:
 *   - High-priority / weak topics scheduled earlier and more frequently
 *   - Spaced repetition: same topic revisited after 1-2 day gaps
 *   - Daily load balanced (not too many tasks per day)
 *   - User preferences respected (available hours per day)
 *   - Missed tasks auto-rescheduled to next available slot
 */
public class StudySchedulerGA {

    // GA parameters
    private static final int POPULATION_SIZE = 60;
    private static final int GENERATIONS = 100;
    private static final double MUTATION_RATE = 0.15;
    private static final double CROSSOVER_RATE = 0.7;
    private static final int TOURNAMENT_SIZE = 5;
    private static final int MAX_TASKS_PER_DAY = 5;
    private static final int ELITISM_COUNT = 2;

    private final Random random = new Random();

    /**
     * Generate an optimized study plan.
     *
     * @param topics        list of topics with priority and subtopics
     * @param weakTopics    topics the user scored poorly on
     * @param numDays       how many days to plan for
     * @param missedTasks   tasks the user missed (to reschedule)
     * @param startDate     first day of the plan
     * @param minutesPerDay available study minutes per day
     * @return optimized schedule
     */
    public StudySchedule generate(
            List<TopicInput> topics,
            List<String> weakTopics,
            int numDays,
            List<TaskInput> missedTasks,
            LocalDate startDate,
            int minutesPerDay
    ) {
        if (topics.isEmpty() && missedTasks.isEmpty()) {
            return StudySchedule.empty(startDate, numDays);
        }

        // Build the pool of tasks that need scheduling
        List<TaskGene> taskPool = buildTaskPool(topics, weakTopics, missedTasks);

        if (taskPool.isEmpty()) {
            return StudySchedule.empty(startDate, numDays);
        }

        // Initialize population
        List<Chromosome> population = initPopulation(taskPool, numDays);

        // Evolve
        for (int gen = 0; gen < GENERATIONS; gen++) {
            // Evaluate fitness
            for (Chromosome c : population) {
                c.fitness = evaluateFitness(c, weakTopics, minutesPerDay);
            }

            // Sort by fitness (higher is better)
            population.sort((a, b) -> Double.compare(b.fitness, a.fitness));

            List<Chromosome> nextGen = new ArrayList<>();

            // Elitism: keep best individuals
            for (int i = 0; i < ELITISM_COUNT && i < population.size(); i++) {
                nextGen.add(population.get(i).copy());
            }

            // Fill rest with crossover + mutation
            while (nextGen.size() < POPULATION_SIZE) {
                Chromosome parent1 = tournamentSelect(population);
                Chromosome parent2 = tournamentSelect(population);

                Chromosome child;
                if (random.nextDouble() < CROSSOVER_RATE) {
                    child = crossover(parent1, parent2, numDays);
                } else {
                    child = parent1.copy();
                }

                if (random.nextDouble() < MUTATION_RATE) {
                    mutate(child, numDays);
                }

                nextGen.add(child);
            }

            population = nextGen;
        }

        // Final evaluation
        for (Chromosome c : population) {
            c.fitness = evaluateFitness(c, weakTopics, minutesPerDay);
        }
        population.sort((a, b) -> Double.compare(b.fitness, a.fitness));

        // Convert best chromosome to schedule
        return chromosomeToSchedule(population.get(0), startDate, numDays);
    }

    // ─────────────────────────────────────────
    // Task pool construction
    // ─────────────────────────────────────────

    private List<TaskGene> buildTaskPool(
            List<TopicInput> topics,
            List<String> weakTopics,
            List<TaskInput> missedTasks
    ) {
        List<TaskGene> pool = new ArrayList<>();
        int id = 1;

        // Add missed tasks with HIGH priority (reschedule)
        for (TaskInput missed : missedTasks) {
            pool.add(new TaskGene(
                    id++,
                    missed.title(),
                    missed.topicLabel(),
                    "HIGH",
                    missed.estimatedMinutes() > 0 ? missed.estimatedMinutes() : 25,
                    TaskGene.TaskType.RESCHEDULED,
                    missed.description()
            ));
        }

        // For each topic, create study tasks
        Set<String> weakSet = new HashSet<>(weakTopics.stream()
                .map(String::toLowerCase)
                .toList());

        for (TopicInput topic : topics) {
            boolean isWeak = weakSet.contains(topic.name().toLowerCase());
            String basePriority = topic.priority() != null ? topic.priority() : "MEDIUM";

            // If weak, bump priority
            String effectivePriority = isWeak ? "HIGH" : basePriority;

            // Reading task
            pool.add(new TaskGene(
                    id++,
                    "Read: " + topic.name(),
                    topic.name(),
                    effectivePriority,
                    30,
                    TaskGene.TaskType.READ,
                    "Read and understand notes for " + topic.name()
            ));

            // Flashcard review
            pool.add(new TaskGene(
                    id++,
                    "Review flashcards: " + topic.name(),
                    topic.name(),
                    effectivePriority,
                    15,
                    TaskGene.TaskType.REVIEW,
                    "Review flashcards and key points for " + topic.name()
            ));

            // Quiz practice
            pool.add(new TaskGene(
                    id++,
                    "Quiz: " + topic.name(),
                    topic.name(),
                    effectivePriority,
                    20,
                    TaskGene.TaskType.QUIZ,
                    "Practice quiz questions for " + topic.name()
            ));

            // Weak topics get an extra revision task
            if (isWeak) {
                pool.add(new TaskGene(
                        id++,
                        "Deep review: " + topic.name(),
                        topic.name(),
                        "HIGH",
                        30,
                        TaskGene.TaskType.DEEP_REVIEW,
                        "Focus session on weak area: " + topic.name()
                ));
            }

            // Subtopics get individual tasks if important
            if (topic.subtopics() != null) {
                for (String sub : topic.subtopics()) {
                    if (isWeak || "HIGH".equalsIgnoreCase(basePriority)) {
                        pool.add(new TaskGene(
                                id++,
                                "Study: " + sub,
                                topic.name(),
                                effectivePriority,
                                20,
                                TaskGene.TaskType.READ,
                                "Study subtopic: " + sub + " under " + topic.name()
                        ));
                    }
                }
            }
        }

        return pool;
    }

    // ─────────────────────────────────────────
    // Population initialization
    // ─────────────────────────────────────────

    private List<Chromosome> initPopulation(List<TaskGene> taskPool, int numDays) {
        List<Chromosome> population = new ArrayList<>();

        for (int i = 0; i < POPULATION_SIZE; i++) {
            Chromosome c = new Chromosome(numDays);

            // Shuffle tasks and assign to random days
            List<TaskGene> shuffled = new ArrayList<>(taskPool);
            Collections.shuffle(shuffled, random);

            for (TaskGene task : shuffled) {
                int day = random.nextInt(numDays);
                c.assignTask(day, task);
            }

            population.add(c);
        }

        return population;
    }

    // ─────────────────────────────────────────
    // Fitness evaluation
    // ─────────────────────────────────────────

    private double evaluateFitness(Chromosome c, List<String> weakTopics, int minutesPerDay) {
        double fitness = 100.0;

        Set<String> weakSet = new HashSet<>(weakTopics.stream()
                .map(String::toLowerCase)
                .toList());

        // 1. Penalize overloaded days
        for (int day = 0; day < c.numDays; day++) {
            List<TaskGene> dayTasks = c.getTasksForDay(day);
            int totalMinutes = dayTasks.stream().mapToInt(t -> t.estimatedMinutes).sum();

            if (totalMinutes > minutesPerDay) {
                fitness -= (totalMinutes - minutesPerDay) * 0.5;
            }

            if (dayTasks.size() > MAX_TASKS_PER_DAY) {
                fitness -= (dayTasks.size() - MAX_TASKS_PER_DAY) * 5;
            }

            // Penalize empty days if there are tasks to fill
            if (dayTasks.isEmpty()) {
                fitness -= 3;
            }
        }

        // 2. Reward high-priority tasks being earlier
        for (int day = 0; day < c.numDays; day++) {
            for (TaskGene task : c.getTasksForDay(day)) {
                int priorityScore = switch (task.priority.toUpperCase()) {
                    case "HIGH" -> 3;
                    case "MEDIUM" -> 2;
                    default -> 1;
                };

                // Earlier days get more reward for high priority
                double dayWeight = 1.0 - ((double) day / c.numDays) * 0.5;
                fitness += priorityScore * dayWeight * 2;
            }
        }

        // 3. Reward weak topics appearing more frequently and earlier
        for (int day = 0; day < c.numDays; day++) {
            for (TaskGene task : c.getTasksForDay(day)) {
                if (weakSet.contains(task.topicLabel.toLowerCase())) {
                    fitness += 4;
                    if (day < c.numDays / 2) {
                        fitness += 2; // extra reward for early scheduling
                    }
                }
            }
        }

        // 4. Reward spaced repetition (same topic revisited with 1-2 day gap)
        Map<String, List<Integer>> topicDays = new HashMap<>();
        for (int day = 0; day < c.numDays; day++) {
            for (TaskGene task : c.getTasksForDay(day)) {
                topicDays.computeIfAbsent(task.topicLabel.toLowerCase(), k -> new ArrayList<>()).add(day);
            }
        }

        for (List<Integer> days : topicDays.values()) {
            Collections.sort(days);
            for (int i = 1; i < days.size(); i++) {
                int gap = days.get(i) - days.get(i - 1);
                if (gap >= 1 && gap <= 2) {
                    fitness += 5; // ideal spacing
                } else if (gap == 0) {
                    fitness -= 2; // same day = bad spacing
                } else if (gap > 3) {
                    fitness -= 1; // too much gap
                }
            }
        }

        // 5. Reward rescheduled tasks being in earliest days
        for (int day = 0; day < c.numDays; day++) {
            for (TaskGene task : c.getTasksForDay(day)) {
                if (task.taskType == TaskGene.TaskType.RESCHEDULED) {
                    if (day == 0) fitness += 8;
                    else if (day == 1) fitness += 5;
                    else fitness += 2;
                }
            }
        }

        // 6. Reward task variety within a day (READ + REVIEW + QUIZ mix)
        for (int day = 0; day < c.numDays; day++) {
            Set<TaskGene.TaskType> types = c.getTasksForDay(day).stream()
                    .map(t -> t.taskType)
                    .collect(Collectors.toSet());
            fitness += types.size() * 1.5;
        }

        return fitness;
    }

    // ─────────────────────────────────────────
    // Selection, Crossover, Mutation
    // ─────────────────────────────────────────

    private Chromosome tournamentSelect(List<Chromosome> population) {
        Chromosome best = null;
        for (int i = 0; i < TOURNAMENT_SIZE; i++) {
            Chromosome candidate = population.get(random.nextInt(population.size()));
            if (best == null || candidate.fitness > best.fitness) {
                best = candidate;
            }
        }
        return best;
    }

    private Chromosome crossover(Chromosome p1, Chromosome p2, int numDays) {
        Chromosome child = new Chromosome(numDays);

        // Single-point crossover on days
        int crossPoint = random.nextInt(numDays);

        for (int day = 0; day < numDays; day++) {
            List<TaskGene> tasks = (day < crossPoint)
                    ? p1.getTasksForDay(day)
                    : p2.getTasksForDay(day);

            for (TaskGene t : tasks) {
                child.assignTask(day, t);
            }
        }

        return child;
    }

    private void mutate(Chromosome c, int numDays) {
        // Swap a random task to a different day
        int fromDay = random.nextInt(numDays);
        List<TaskGene> fromTasks = c.getTasksForDay(fromDay);
        if (fromTasks.isEmpty()) return;

        int taskIdx = random.nextInt(fromTasks.size());
        TaskGene task = fromTasks.remove(taskIdx);

        int toDay = random.nextInt(numDays);
        c.assignTask(toDay, task);
    }

    // ─────────────────────────────────────────
    // Convert to output
    // ─────────────────────────────────────────

    private StudySchedule chromosomeToSchedule(Chromosome best, LocalDate startDate, int numDays) {
        List<StudySchedule.ScheduleDay> days = new ArrayList<>();

        for (int d = 0; d < numDays; d++) {
            LocalDate date = startDate.plusDays(d);
            List<TaskGene> dayTasks = best.getTasksForDay(d);

            // Sort: rescheduled first, then by priority
            dayTasks.sort((a, b) -> {
                if (a.taskType == TaskGene.TaskType.RESCHEDULED && b.taskType != TaskGene.TaskType.RESCHEDULED)
                    return -1;
                if (b.taskType == TaskGene.TaskType.RESCHEDULED && a.taskType != TaskGene.TaskType.RESCHEDULED)
                    return 1;
                return Integer.compare(priorityWeight(b.priority), priorityWeight(a.priority));
            });

            List<StudySchedule.ScheduleTask> tasks = new ArrayList<>();
            for (TaskGene gene : dayTasks) {
                tasks.add(new StudySchedule.ScheduleTask(
                        gene.id,
                        gene.title,
                        gene.description,
                        gene.topicLabel,
                        gene.priority,
                        gene.estimatedMinutes,
                        gene.taskType.name(),
                        false
                ));
            }

            int totalMinutes = dayTasks.stream().mapToInt(t -> t.estimatedMinutes).sum();

            days.add(new StudySchedule.ScheduleDay(
                    "Day " + (d + 1),
                    date.toString(),
                    tasks,
                    totalMinutes
            ));
        }

        return new StudySchedule(days, best.fitness);
    }

    private int priorityWeight(String priority) {
        return switch (priority.toUpperCase()) {
            case "HIGH" -> 3;
            case "MEDIUM" -> 2;
            case "LOW" -> 1;
            default -> 0;
        };
    }

    // ═══════════════════════════════════════
    // Inner types
    // ═══════════════════════════════════════

    static class TaskGene {
        enum TaskType { READ, REVIEW, QUIZ, DEEP_REVIEW, RESCHEDULED }

        final int id;
        final String title;
        final String topicLabel;
        final String priority;
        final int estimatedMinutes;
        final TaskType taskType;
        final String description;

        TaskGene(int id, String title, String topicLabel, String priority,
                 int estimatedMinutes, TaskType taskType, String description) {
            this.id = id;
            this.title = title;
            this.topicLabel = topicLabel;
            this.priority = priority;
            this.estimatedMinutes = estimatedMinutes;
            this.taskType = taskType;
            this.description = description;
        }
    }

    static class Chromosome {
        final int numDays;
        final List<List<TaskGene>> days;
        double fitness = 0;

        Chromosome(int numDays) {
            this.numDays = numDays;
            this.days = new ArrayList<>();
            for (int i = 0; i < numDays; i++) {
                this.days.add(new ArrayList<>());
            }
        }

        void assignTask(int day, TaskGene task) {
            if (day >= 0 && day < numDays) {
                days.get(day).add(task);
            }
        }

        List<TaskGene> getTasksForDay(int day) {
            return days.get(day);
        }

        Chromosome copy() {
            Chromosome c = new Chromosome(numDays);
            for (int i = 0; i < numDays; i++) {
                c.days.get(i).addAll(this.days.get(i));
            }
            c.fitness = this.fitness;
            return c;
        }
    }

    // ═══════════════════════════════════════
    // Input / Output records
    // ═══════════════════════════════════════

    public record TopicInput(String name, String priority, List<String> subtopics, Double score) {}

    public record TaskInput(String title, String topicLabel, String description, int estimatedMinutes) {}

    public record StudySchedule(List<ScheduleDay> days, double fitnessScore) {
        public record ScheduleDay(String label, String date, List<ScheduleTask> tasks, int totalMinutes) {}
        public record ScheduleTask(int id, String title, String description, String topicLabel,
                                   String priority, int estimatedMinutes, String taskType, boolean completed) {}

        public static StudySchedule empty(LocalDate startDate, int numDays) {
            List<ScheduleDay> days = new ArrayList<>();
            for (int i = 0; i < numDays; i++) {
                days.add(new ScheduleDay(
                        "Day " + (i + 1),
                        startDate.plusDays(i).toString(),
                        List.of(),
                        0
                ));
            }
            return new StudySchedule(days, 0);
        }
    }
}
